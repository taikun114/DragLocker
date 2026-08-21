import AppKit
import SwiftUI
import QuartzCore
import MachO

/// フォーカスを奪わないように設定されたカスタムウィンドウ
class PointerIndicatorWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 各ディスプレイごとに配置される全画面オーバーレイ
private class ScreenOverlay {
    let screen: NSScreen
    let window: PointerIndicatorWindow
    let containerView: NSView
    private(set) var indicatorHostingView: NSHostingView<CursorView>
    
    // マウス位置予測用
    private var lastMousePoint: NSPoint?
    private var lastSampleTime: CFTimeInterval = 0
    private var velocityX: CGFloat = 0
    private var velocityY: CGFloat = 0
    
    init(screen: NSScreen) {
        self.screen = screen
        
        let window = PointerIndicatorWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.animationBehavior = .none
        
        let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = container
        
        let hostingView = NSHostingView(rootView: CursorView())
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        let fixedSize = NSSize(width: 80, height: 80)
        hostingView.frame = NSRect(origin: NSPoint(x: -200, y: -200), size: fixedSize)
        container.addSubview(hostingView)
        
        self.window = window
        self.containerView = container
        self.indicatorHostingView = hostingView
    }
    
    func recreateHostingView() {
        indicatorHostingView.removeFromSuperview()
        
        let hostingView = NSHostingView(rootView: CursorView())
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        let fixedSize = NSSize(width: 80, height: 80)
        hostingView.frame = NSRect(origin: NSPoint(x: -200, y: -200), size: fixedSize)
        containerView.addSubview(hostingView)
        
        self.indicatorHostingView = hostingView
    }
    
    func show() {
        resetPrediction()
        window.setFrame(screen.frame, display: true)
        containerView.frame = NSRect(origin: .zero, size: screen.frame.size)
        window.orderFrontRegardless()
    }
    
    func hide() {
        resetPrediction()
        window.orderOut(nil)
    }
    
    func resetPrediction() {
        lastMousePoint = nil
        lastSampleTime = 0
        velocityX = 0
        velocityY = 0
    }
    
    func updatePosition(targetTimestamp: CFTimeInterval) {
        let now = CACurrentMediaTime()
        // イベントストリームを介さず、WindowServer直結の最新物理マウス座標を取得
        let rawMouseInWindow = window.mouseLocationOutsideOfEventStream
        
        // 速度ベクトル（Velocity）の計算
        if let lastPoint = lastMousePoint, lastSampleTime > 0 {
            let dt = now - lastSampleTime
            if dt > 0.0005 && dt < 0.05 {
                let instantVx = (rawMouseInWindow.x - lastPoint.x) / CGFloat(dt)
                let instantVy = (rawMouseInWindow.y - lastPoint.y) / CGFloat(dt)
                
                // 方向転換（内積が負）を検知した場合は慣性をリセットして即座に切り返しに追従
                let dot = instantVx * velocityX + instantVy * velocityY
                if dot < 0 {
                    velocityX = instantVx
                    velocityY = instantVy
                } else {
                    velocityX = velocityX * 0.25 + instantVx * 0.75
                    velocityY = velocityY * 0.25 + instantVy * 0.75
                }
            } else if dt >= 0.05 {
                velocityX = 0
                velocityY = 0
            }
        }
        
        lastMousePoint = rawMouseInWindow
        lastSampleTime = now
        
        // 次回フレーム表示タイミングへの先回り予測時間幅
        let frameDuration = max(0.005, min(0.016, targetTimestamp - now))
        let speed = hypot(velocityX, velocityY)
        
        let predictedX: CGFloat
        let predictedY: CGFloat
        if speed > 15.0 {
            predictedX = rawMouseInWindow.x + velocityX * CGFloat(frameDuration)
            predictedY = rawMouseInWindow.y + velocityY * CGFloat(frameDuration)
        } else {
            predictedX = rawMouseInWindow.x
            predictedY = rawMouseInWindow.y
            velocityX = 0
            velocityY = 0
        }
        
        let xOffset = -40.0 + EventManager.shared.effectiveIconSetting(key: "xOffset")
        let yOffset = -40.0 - EventManager.shared.effectiveIconSetting(key: "yOffset")
        
        let newOrigin = NSPoint(
            x: (predictedX + xOffset).rounded(),
            y: (predictedY + yOffset).rounded()
        )
        
        let iconRect = NSRect(origin: newOrigin, size: CGSize(width: 80, height: 80))
        let screenLocalBounds = NSRect(origin: .zero, size: screen.frame.size)
        
        // 画面内または画面境界付近（交差する場合）のみ更新して描画
        if screenLocalBounds.intersects(iconRect) {
            indicatorHostingView.isHidden = false
            if indicatorHostingView.frame.origin != newOrigin {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                indicatorHostingView.frame.origin = newOrigin
                CATransaction.commit()
            }
        } else {
            if !indicatorHostingView.isHidden {
                indicatorHostingView.isHidden = true
            }
        }
    }
}

class CursorManager {
    static let shared = CursorManager()
    
    /// アニメーションの時間（秒）
    static let animationDuration: Double = 0.1
    
    private static var timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
    
    private var overlays: [ScreenOverlay] = []
    private var displayLink: CADisplayLink?
    
    init() {
        setupOverlays()
        setupScreenChangeObserver()
    }
    
    private func setupOverlays() {
        overlays.forEach { $0.hide() }
        overlays = NSScreen.screens.map { ScreenOverlay(screen: $0) }
    }
    
    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupOverlays()
            if !LockStateManager.shared.lockedButtons.isEmpty {
                self?.showCustomCursor()
            }
        }
    }
    
    /// インジケーターを非表示
    func hideCustomCursor() {
        stopDisplayLink()
        
        // 現在のアニメーション設定に応じた待機時間を設定（ポップ系は0.3秒、それ以外は0.1秒）
        let animationType = EventManager.shared.effectiveSetting?.iconAnimation ?? EventManager.shared.iconAnimation
        let duration: Double = (animationType == .pop || animationType == .popPlus) ? 0.3 : Self.animationDuration
        
        // アニメーションが完了するのを確実に待ってからウィンドウを隠す (0.05sのマージン)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak self] in
            guard let self = self else { return }
            // その間に再度ロックされた場合は隠さない
            if LockStateManager.shared.lockedButtons.isEmpty {
                self.overlays.forEach { $0.hide() }
            }
        }
    }
    
    /// カーソルのスタイルを更新
    func updateCursorStyle() {
        overlays.forEach { $0.recreateHostingView() }
    }
    
    /// インジケーターを表示
    func showCustomCursor() {
        if overlays.isEmpty {
            setupOverlays()
        }
        
        overlays.forEach { $0.show() }
        updatePosition(targetTimestamp: CACurrentMediaTime() + 0.0083)
        
        // CADisplayLinkによる画面リフレッシュ同期と低遅延トラッキングを開始
        startDisplayLink()
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        
        guard let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        // V-Syncの締め切り（targetTimestamp）直前（約1.5ms前）まで待機して最新のマウス物理座標を取得（Just-In-Time）
        let targetTimestamp = link.targetTimestamp
        let now = CACurrentMediaTime()
        let wakeAt = targetTimestamp - 0.0015
        if wakeAt > now {
            let durationSeconds = wakeAt - now
            let durationNanos = UInt64(durationSeconds * 1_000_000_000.0)
            let machDuration = durationNanos * UInt64(Self.timebaseInfo.denom) / UInt64(Self.timebaseInfo.numer)
            mach_wait_until(mach_absolute_time() + machDuration)
        }
        
        updatePosition(targetTimestamp: targetTimestamp)
    }
    
    /// インジケーターの位置を更新
    func updatePosition(targetTimestamp: CFTimeInterval? = nil) {
        let deadline = targetTimestamp ?? (CACurrentMediaTime() + 0.0083)
        for overlay in overlays {
            overlay.updatePosition(targetTimestamp: deadline)
        }
    }
}

struct CursorView: View {
    @ObservedObject var eventManager = EventManager.shared
    @ObservedObject var lockState = LockStateManager.shared
    
    // 初回表示時や状態変化時に確実にアニメーションを発生させるためのローカル状態
    @State private var isVisible = false
    
    var body: some View {
        let setting = eventManager.effectiveSetting ?? eventManager.resolveSetting(for: nil)
        let style = setting.pointerIconStyle
        let isLocked = !lockState.lockedButtons.isEmpty
        let scale = EventManager.shared.effectiveIconSetting(key: "scale")
        
        ZStack(alignment: .center) {
            if style == .padlock {
                Image("Pointer_Locked")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10 * scale, height: 16 * scale)
            } else if style == .dot {
                ZStack(alignment: .center) {
                    Circle().fill(Color.white).frame(width: 8 * scale, height: 8 * scale)
                    Circle().fill(Color.black).frame(width: 6 * scale, height: 6 * scale)
                }
            } else if style == .largeRing {
                Circle()
                    .stroke(Color.white, lineWidth: 4 * scale)
                    .frame(width: 40 * scale, height: 40 * scale)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2 * scale)
                            .frame(width: 40 * scale, height: 40 * scale)
                    )
                    .padding(4 * scale)
            } else if style == .focus {
                // ピクセルパーフェクトなフォーカスアイコン (48x48)
                ZStack {
                    // 左上
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .topLeading, containerSize: 40 * scale)
                    // 右上
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .topTrailing, containerSize: 40 * scale)
                    // 左下
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .bottomLeading, containerSize: 40 * scale)
                    // 右下
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .bottomTrailing, containerSize: 40 * scale)
                }
                .frame(width: 40 * scale, height: 40 * scale)
                .padding(4 * scale)
            } else if style == .trafficLight {
                HStack(spacing: 3 * scale) {
                    // 左クリック (緑)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 7 * scale, height: 7 * scale)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 7 * scale, height: 7 * scale)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 7 * scale, height: 7 * scale)
                }
                .padding(.horizontal, 4 * scale)
                .padding(.vertical, 3 * scale)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0 * scale)
                        )
                )
            } else if style == .smallTrafficLight {
                HStack(spacing: 2 * scale) {
                    // 左クリック (緑)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 5 * scale, height: 5 * scale)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 5 * scale, height: 5 * scale)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 5 * scale, height: 5 * scale)
                }
                .padding(.horizontal, 2 * scale)
                .padding(.vertical, 1.5 * scale)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0 * scale)
                        )
                )
            } else if style == .trafficLightVertical {
                VStack(spacing: 3 * scale) {
                    // 左クリック (緑)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 7 * scale, height: 7 * scale)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 7 * scale, height: 7 * scale)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 7 * scale, height: 7 * scale)
                }
                .padding(.horizontal, 3 * scale)
                .padding(.vertical, 4 * scale)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0 * scale)
                        )
                )
            } else if style == .smallTrafficLightVertical {
                VStack(spacing: 2 * scale) {
                    // 左クリック (緑)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 5 * scale, height: 5 * scale)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 5 * scale, height: 5 * scale)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(lockState.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 5 * scale, height: 5 * scale)
                }
                .padding(.horizontal, 2 * scale)
                .padding(.vertical, 2.5 * scale)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0 * scale)
                        )
                )
            } else if style == .textHorizontal {
                HStack(spacing: 1 * scale) {
                    Text(verbatim: "L")
                        .opacity(lockState.lockedButtons.contains(.left) ? 1.0 : 0.5)
                    Text(verbatim: "M")
                        .opacity(lockState.lockedButtons.contains(.middle) ? 1.0 : 0.5)
                        .padding(.leading, -1.5 * scale) // Lの右上の余白を埋めるために少し詰める
                    Text(verbatim: "R")
                        .opacity(lockState.lockedButtons.contains(.right) ? 1.0 : 0.5)
                }
                .font(.system(size: 11 * scale, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 4 * scale)
                .padding(.vertical, 2 * scale)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0 * scale)
                        )
                )
            } else if style == .textVertical {
                VStack(spacing: -2.8 * scale) { // 極限まで詰める
                    Text(verbatim: "L")
                        .opacity(lockState.lockedButtons.contains(.left) ? 1.0 : 0.5)
                    Text(verbatim: "M")
                        .opacity(lockState.lockedButtons.contains(.middle) ? 1.0 : 0.5)
                    Text(verbatim: "R")
                        .opacity(lockState.lockedButtons.contains(.right) ? 1.0 : 0.5)
                }
                .font(.system(size: 8 * scale, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 3 * scale)
                .padding(.vertical, 3 * scale)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0 * scale)
                        )
                )
            } else if style == .custom {
                if let image = eventManager.cachedCustomIconImage {
                    // キャッシュは既にトリミング・リサイズ済み
                    // 80x80のコンテナに合わせて表示サイズを決定する
                    let fitScale = min(1.0, 80.0 / max(1, image.size.width), 80.0 / max(1, image.size.height))
                    let displayWidth = image.size.width * fitScale * scale
                    let displayHeight = image.size.height * fitScale * scale
                    
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayHeight)
                } else {
                    Color.clear
                }
            }
        }
        .frame(width: 80, height: 80, alignment: .center) // 全てのスタイルを80x80の中心に固定して配置
        .clipped()
        .opacity(EventManager.shared.effectiveIconSetting(key: "opacity"))
        
        // アニメーション設定の適用
        // isVisible (ローカル状態) の変化に連動してアニメーションさせる
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(currentScale(animationType: setting.iconAnimation, isLocked: isVisible, style: style))
        .animation(currentAnimation(animationType: setting.iconAnimation), value: isVisible)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            // ウィンドウが表示されたタイミングで状態を同期し、アニメーションを開始させる
            // 確実を期すため、次のメインループで実行
            DispatchQueue.main.async {
                isVisible = isLocked
            }
        }
        .onChange(of: isLocked) { oldValue, newValue in
            isVisible = newValue
        }
    }
    
    /// 現在のロック状態とアニメーション設定に基づいたスケールを返します
    private func currentScale(animationType: IconAnimation, isLocked: Bool, style: IconStyle) -> CGFloat {
        if isLocked {
            return 1.0
        }
        
        switch animationType {
        case .default:
            return (style == .focus) ? 1.2 : 1.0
        case .none, .fade:
            return 1.0
        case .pop, .popPlus, .scale:
            return 0.0
        case .focus:
            return 1.2
        case .focusPlus:
            return 1.4
        }
    }
    
    /// アニメーション設定に基づいたAnimationオブジェクトを返します
    private func currentAnimation(animationType: IconAnimation) -> Animation? {
        switch animationType {
        case .default, .fade, .scale, .focus, .focusPlus:
            return .easeOut(duration: CursorManager.animationDuration)
        case .none:
            return nil
        case .pop:
            // 0.3秒で、表示時はオーバーシュートして戻るような挙動
            return .spring(response: 0.3, dampingFraction: 0.7)
        case .popPlus:
            // より強調されたポップ（減衰率を下げる）
            return .spring(response: 0.3, dampingFraction: 0.5)
        }
    }
}

// 1x環境（ドットバイドット）でクッキリ表示させるためのコーナーパーツ
struct FocusCorner: View {
    let length: CGFloat
    let thickness: CGFloat
    let innerThickness: CGFloat
    let alignment: Alignment
    var containerSize: CGFloat = 40.0 // コンテナサイズを可変にする
    
    var body: some View {
        ZStack {
            // 外側の白い枠 (厚さ 4px)
            whiteShape
                .fill(Color.white)
            
            // 内側の黒い塗り (厚さ 2px)
            blackShape
                .fill(Color.black)
        }
        .frame(width: length, height: length)
        .frame(width: containerSize, height: containerSize, alignment: alignment)
    }
    
    private var whiteShape: some Shape {
        SpecificCornerShape(length: length, thickness: thickness, alignment: alignment)
    }
    
    private var blackShape: some Shape {
        // 内側の黒い芯 (厚さ 2px * scale)
        // 外側の枠との差分から適切なインセット量を計算する（スケールに連動させる）
        let inset = (thickness - innerThickness) / 2
        // 両端（コーナー側と先端側）に均等なボーダーを出すため、長さは差分分短縮する
        return SpecificCornerShape(length: length - (thickness - innerThickness), thickness: innerThickness, alignment: alignment, inset: inset)
    }
}

// 隅ごとにパスを独立させて描くことで、反転によるボケを防ぐシェイプ
struct SpecificCornerShape: Shape {
    let length: CGFloat
    let thickness: CGFloat
    let alignment: Alignment
    var inset: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        switch alignment {
        case .topLeading:
            // 左上
            path.addRect(CGRect(x: inset, y: inset, width: length, height: thickness))
            path.addRect(CGRect(x: inset, y: inset, width: thickness, height: length))
        case .topTrailing:
            // 右上
            path.addRect(CGRect(x: w - length - inset, y: inset, width: length, height: thickness))
            path.addRect(CGRect(x: w - thickness - inset, y: inset, width: thickness, height: length))
        case .bottomLeading:
            // 左下
            path.addRect(CGRect(x: inset, y: h - thickness - inset, width: length, height: thickness))
            path.addRect(CGRect(x: inset, y: h - length - inset, width: thickness, height: length))
        case .bottomTrailing:
            // 右下
            path.addRect(CGRect(x: w - length - inset, y: h - thickness - inset, width: length, height: thickness))
            path.addRect(CGRect(x: w - thickness - inset, y: h - length - inset, width: thickness, height: length))
        default:
            break
        }
        
        return path
    }
}
