import AppKit
import SwiftUI

/// フォーカスを奪わないように設定されたカスタムウィンドウ
class PointerIndicatorWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class CursorManager {
    static let shared = CursorManager()
    
    /// アニメーションの時間（秒）
    static let animationDuration: Double = 0.1
    
    private var cursorWindow: NSWindow?
    private var positionUpdateTimer: Timer?
    
    init() {
        setupCursorWindow()
        updateCursorStyle()
    }
    
    private func setupCursorWindow() {
        let window = PointerIndicatorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.cursorWindow)))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.animationBehavior = .none
        
        self.cursorWindow = window
    }
    
    /// インジケーターを非表示
    func hideCustomCursor() {
        stopPositionUpdateTimer()
        
        // アニメーション（0.1s）が完了するのを確実に待ってからウィンドウを隠す (0.05sのマージン)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationDuration + 0.05) {
            // その間に再度ロックされた場合は隠さない
            if EventManager.shared.lockedButtons.isEmpty {
                self.cursorWindow?.orderOut(nil)
            }
        }
    }
    
    /// カーソルのスタイルを更新
    func updateCursorStyle() {
        guard let window = cursorWindow else { return }
        
        let contentView = NSHostingView(rootView: CursorView())
        
        // NSHostingViewがcontentViewに設定されると自動的にウィンドウのmin/maxサイズを
        // 更新しようとし、制約更新の無限ループを引き起こすため、すべての自動サイズ管理を無効化する
        contentView.sizingOptions = []
        
        let fixedSize = NSSize(width: 80, height: 80)
        contentView.setFrameSize(fixedSize)
        window.contentView = contentView
        window.setContentSize(fixedSize)
    }
    
    /// インジケーターを表示
    func showCustomCursor() {
        guard let window = cursorWindow else { return }
        
        updatePosition()
        window.orderFront(nil)
        
        // 高速移動時のズレを防ぎ、停止時にも正確な位置に配置されるようタイマーで更新を開始
        startPositionUpdateTimer()
    }
    
    private func startPositionUpdateTimer() {
        positionUpdateTimer?.invalidate()
        // 120Hzでリフレッシュして滑らかな追従を実現
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
        positionUpdateTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func stopPositionUpdateTimer() {
        positionUpdateTimer?.invalidate()
        positionUpdateTimer = nil
    }
    
    /// 指定された位置にウィンドウの位置を更新
    func updatePosition(to location: CGPoint? = nil) {
        guard let window = cursorWindow else { return }
        
        // 指定がない場合は現在のマウス位置を取得
        let mouseLocation = location ?? NSEvent.mouseLocation
        
        // スタイルごとの位置調整
        let style = EventManager.shared.pointerIconStyle
        let xOffset: Double
        let yOffset: Double
        
        switch style {
        case .padlock:
            xOffset = 12.0
            yOffset = -7.0
        case .dot:
            xOffset = 12.0
            yOffset = -4.0
        case .largeRing:
            xOffset = -24.0
            yOffset = -24.0
        case .focus:
            xOffset = -24.0
            yOffset = -24.0
        case .trafficLight:
            xOffset = 12.0
            yOffset = -6.5 // 高さ(13)の半分
        case .smallTrafficLight:
            xOffset = 12.0
            yOffset = -4.5 // 高さ(9)の半分
        case .trafficLightVertical:
            xOffset = 14.0
            yOffset = -17.5 // 高さ(35)の半分
        case .smallTrafficLightVertical:
            xOffset = 14.0
            yOffset = -12.0 // 高さ(24)の半分
        case .textHorizontal:
            xOffset = 12.0
            yOffset = -8.0 // -5.0 と -10.0 の間をとって調整
        case .textVertical:
            xOffset = 13.0
            yOffset = -14.0 // 以前よりポインタに近づける
        }
        
        let newOrigin = NSPoint(
            x: (mouseLocation.x + xOffset).rounded(),
            y: (mouseLocation.y + yOffset).rounded()
        )
        
        window.setFrameOrigin(newOrigin)
    }
}

struct CursorView: View {
    @ObservedObject var eventManager = EventManager.shared
    
    var body: some View {
        let style = eventManager.pointerIconStyle
        let isLocked = !eventManager.lockedButtons.isEmpty
        
        // スタイルごとのアニメーション用スケール
        let startScale: CGFloat = (style == .focus) ? 1.2 : 1.0
        
        ZStack(alignment: .center) {
            if style == .padlock {
                Image("Pointer_Locked")
            } else if style == .dot {
                ZStack(alignment: .center) {
                    Circle().fill(Color.white).frame(width: 8, height: 8)
                    Circle().fill(Color.black).frame(width: 6, height: 6)
                }
            } else if style == .largeRing {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 40, height: 40)
                    )
                    .padding(4)
            } else if style == .focus {
                // ピクセルパーフェクトなフォーカスアイコン (48x48)
                ZStack {
                    // 左上
                    FocusCorner(length: 12, thickness: 4, innerThickness: 2, alignment: .topLeading)
                    // 右上
                    FocusCorner(length: 12, thickness: 4, innerThickness: 2, alignment: .topTrailing)
                    // 左下
                    FocusCorner(length: 12, thickness: 4, innerThickness: 2, alignment: .bottomLeading)
                    // 右下
                    FocusCorner(length: 12, thickness: 4, innerThickness: 2, alignment: .bottomTrailing)
                }
                .frame(width: 40, height: 40)
                .padding(4)
            } else if style == .trafficLight {
                HStack(spacing: 3) {
                    // 左クリック (緑)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 7, height: 7)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 7, height: 7)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0)
                        )
                )
            } else if style == .smallTrafficLight {
                HStack(spacing: 2) {
                    // 左クリック (緑)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 5, height: 5)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 5, height: 5)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 5, height: 5)
                }
                .padding(.horizontal, 2.5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0)
                        )
                )
            } else if style == .trafficLightVertical {
                VStack(spacing: 3) {
                    // 左クリック (緑)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 7, height: 7)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 7, height: 7)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0)
                        )
                )
            } else if style == .smallTrafficLightVertical {
                VStack(spacing: 2) {
                    // 左クリック (緑)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.left) ? Color.green : Color.gray)
                        .frame(width: 5, height: 5)
                    
                    // 中クリック (黄)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.middle) ? Color.yellow : Color.gray)
                        .frame(width: 5, height: 5)
                    
                    // 右クリック (赤)
                    Circle()
                        .fill(eventManager.lockedButtons.contains(.right) ? Color.red : Color.gray)
                        .frame(width: 5, height: 5)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0)
                        )
                )
            } else if style == .textHorizontal {
                HStack(spacing: 1) {
                    Text(verbatim: "L")
                        .opacity(eventManager.lockedButtons.contains(.left) ? 1.0 : 0.5)
                    Text(verbatim: "M")
                        .opacity(eventManager.lockedButtons.contains(.middle) ? 1.0 : 0.5)
                        .padding(.leading, -1.5) // Lの右上の余白を埋めるために少し詰める
                    Text(verbatim: "R")
                        .opacity(eventManager.lockedButtons.contains(.right) ? 1.0 : 0.5)
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0)
                        )
                )
            } else if style == .textVertical {
                VStack(spacing: -2.8) { // 極限まで詰める
                    Text(verbatim: "L")
                        .opacity(eventManager.lockedButtons.contains(.left) ? 1.0 : 0.5)
                    Text(verbatim: "M")
                        .opacity(eventManager.lockedButtons.contains(.middle) ? 1.0 : 0.5)
                    Text(verbatim: "R")
                        .opacity(eventManager.lockedButtons.contains(.right) ? 1.0 : 0.5)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.0)
                        )
                )
            }
        }
        // コンテンツ全体にアニメーションを適用
        // isLocked (ドラッグ中か) の変化に連動して自動的にアニメーションする
        .opacity(isLocked ? 1.0 : 0.0)
        .scaleEffect(isLocked ? 1.0 : startScale)
        .animation(.easeOut(duration: CursorManager.animationDuration), value: isLocked)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
        // 内側の黒い芯 (厚さ 2px)
        // 1pxずつ上下左右にインセット。さらに先端（切り口）に白いボーダーを出すため、長さも2px短縮する。
        SpecificCornerShape(length: length - 2, thickness: innerThickness, alignment: alignment, inset: 1)
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
