import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement

enum EventManagerState: Equatable, Sendable {
    case idle
    case holding // マウスダウン中、待機
    case locked  // ロック状態
}

enum IconStyle: String, CaseIterable, Sendable {
    case padlock = "南京錠"
    case dot = "ドット"
}

class EventManager: ObservableObject {
    static let shared = EventManager()
    
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    
    @Published var isTrusted: Bool = false
    @Published var isEnabled: Bool = true // 一時的な機能の有効・無効状態
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var state: EventManagerState = .idle {
        didSet {
            DispatchQueue.main.async {
                self.isLocked = (self.state == .locked)
            }
        }
    }
    
    @Published var isLocked: Bool = false {
        didSet {
            if isSoundEnabled && oldValue != isLocked {
                // ロック時、または解除時にシステム音を鳴らす
                NSSound.beep()
            }
            
            // アイコン表示設定が有効な場合のみカーソルの表示切り替え
            DispatchQueue.main.async {
                if self.isLocked && self.isIconEnabled {
                    CursorManager.shared.showCustomCursor()
                } else {
                    CursorManager.shared.hideCustomCursor()
                }
            }
        }
    }
    private var holdTimer: Timer?
    
    @Published var isSoundEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "isSoundEnabled")
        }
    }
    
    @Published var isIconEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isIconEnabled, forKey: "isIconEnabled")
            // 設定がオフになった瞬間に、もし表示されていれば隠す
            if !isIconEnabled {
                DispatchQueue.main.async {
                    CursorManager.shared.hideCustomCursor()
                }
            }
        }
    }
    
    @Published var pointerIconStyle: IconStyle = .padlock {
        didSet {
            UserDefaults.standard.set(pointerIconStyle.rawValue, forKey: "pointerIconStyle")
        }
    }
    
    @Published var isLaunchAtLoginEnabled: Bool = false {
        didSet {
            // 現在の状態と異なる場合のみ更新（無限ループ防止）
            let currentStatus = SMAppService.mainApp.status
            if (isLaunchAtLoginEnabled && currentStatus != .enabled) || (!isLaunchAtLoginEnabled && currentStatus == .enabled) {
                updateLaunchAtLogin(enabled: isLaunchAtLoginEnabled)
            }
        }
    }
    
    @Published var lockDelay: TimeInterval = 1.0 {
        didSet {
            UserDefaults.standard.set(lockDelay, forKey: "lockDelay")
        }
    }
    
    init() {
        // 保存された設定の読み込み
        let savedDelay = UserDefaults.standard.double(forKey: "lockDelay")
        if savedDelay > 0 {
            self.lockDelay = savedDelay
        } else {
            self.lockDelay = 1.0
        }
        
        self.isSoundEnabled = UserDefaults.standard.bool(forKey: "isSoundEnabled")
        self.isIconEnabled = UserDefaults.standard.bool(forKey: "isIconEnabled")
        if let savedStyle = UserDefaults.standard.string(forKey: "pointerIconStyle"), let style = IconStyle(rawValue: savedStyle) {
            self.pointerIconStyle = style
        }
        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        
        // アプリがアクティブになったときに権限を再チェックする（システム設定で変更された場合に対応）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkAccessibilityPermissions),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    func start() {
        checkAccessibilityPermissions()
    }
    
    @objc func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        print("Checking Accessibility Permissions: \(accessEnabled)")
        
        DispatchQueue.main.async {
            self.isTrusted = accessEnabled
            if self.isTrusted {
                self.setupEventTap()
            }
        }
    }
    
    func requestAccessibilityPermissions() {
        print("Requesting Accessibility Permissions...")
        
        // 1. システムにプロンプトを表示させる標準的な方法を試行
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        
        // 2. 実際にEvent Tapを作成しようと試みることで、システムに権限が必要であることを示し、プロンプトを誘発する
        // (isTrustedがfalseでも、プロンプトを出すためにあえて呼び出す)
        setupEventTap(force: true)
        
        // 3. 状態を再チェック
        checkAccessibilityPermissions()
    }
    
    private func setupEventTap(force: Bool = false) {
        // 通常は権限がある場合のみ実行するが、forceがtrueの場合はプロンプト誘発のために続行する
        if !isTrusted && !force { return }
        if eventTap != nil { return }
        
        print("Attempting to create event tap to trigger system prompt if needed...")
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.leftMouseUp.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)
        
        // Cのコールバック関数に self を渡すため、Unmanaged を使用
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // cghidEventTap を使用することで、どのアプリにフォーカスがあっても全イベントをキャッチできる
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: userInfo
        )
        
        guard let tap = eventTap else {
            print("Failed to create event tap")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            // メインRunLoopに追加することで確実にイベントが処理される
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Event tap successfully set up")
        }
    }
    
    // イベントの送信先がDragLockerアプリ自身かどうかをPIDで判定する（スレッドセーフ）
    private func isEventTargetingOwnApp(event: CGEvent) -> Bool {
        let targetPID = event.getIntegerValueField(.eventTargetUnixProcessID)
        return targetPID == Int64(ownPID)
    }
    
    // イベント処理のエントリーポイント
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        // macOSがタイムアウト等でイベントタップを無効化した場合、再有効化する
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("Event tap was disabled by system, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        // アプリケーション機能が一時停止中の場合は何も処理せずイベントを流す
        guard isEnabled else { return Unmanaged.passRetained(event) }
        
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53 /* Escape key */ {
                if state == .locked {
                    print("Escape pressed: Releasing lock")
                    releaseLock()
                } else if state == .holding {
                    print("Escape pressed: Canceling hold")
                    cancelHold()
                }
            }
            return Unmanaged.passRetained(event) // キーボードイベントはそのまま通す
        }
        
        if type == .leftMouseDown {
            // DragLockerアプリ自身へのクリックではロック機能を発動しない
            if isEventTargetingOwnApp(event: event) {
                print("Mouse down: Targeting own app (PID: \(ownPID)), ignoring")
                if state == .locked {
                    releaseLock()
                } else if state == .holding {
                    cancelHold()
                }
                return Unmanaged.passRetained(event)
            }
            
            if state == .idle {
                print("Mouse down: Starting hold timer")
                state = .holding
                DispatchQueue.main.async {
                    self.startTimer()
                }
            } else if state == .locked {
                print("Mouse down while locked: Releasing lock")
                releaseLock()
                // ロック中にもう一度クリックされたらロック解除し、新しいmouseDownはそのまま通す
            }
            return Unmanaged.passRetained(event)
        }
        
        if type == .leftMouseUp {
            if state == .holding {
                // タイマー発火前に離された -> 通常クリック
                print("Mouse up: Normal click, canceling timer")
                cancelHold()
                return Unmanaged.passRetained(event)
            } else if state == .locked {
                // ロック中に物理ボタンが離された -> 握りつぶしてOSに渡さない（ロック状態を維持）
                print("Mouse up while locked: Ignoring to keep the lock")
                return nil
            }
        }
        
        if type == .leftMouseDragged || type == .mouseMoved {
            if state == .locked {
                // カスタムカーソルの位置を更新
                DispatchQueue.main.async {
                    CursorManager.shared.updatePosition()
                }
                
                if type == .mouseMoved {
                    // 通常のマウス移動イベントをドラッグイベントに変換してOSに渡す
                    event.type = .leftMouseDragged
                }
                return Unmanaged.passRetained(event)
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func startTimer() {
        holdTimer?.invalidate()
        // RunLoop.commonモードで登録することで、メニューバーのメニュー表示中などでもタイマーが動作する
        let timer = Timer(timeInterval: lockDelay, repeats: false) { [weak self] _ in
            // stateプロパティへのアクセスはメインスレッドで行う
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.state == .holding {
                    print("Timer fired: Lock active!")
                    self.state = .locked
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }
    
    private func cancelHold() {
        state = .idle
        DispatchQueue.main.async {
            self.holdTimer?.invalidate()
            self.holdTimer = nil
        }
    }
    
    private func releaseLock() {
        state = .idle
        postSyntheticMouseUp()
    }
    
    func forceUnlock() {
        if state == .locked {
            releaseLock()
        } else if state == .holding {
            cancelHold()
        }
    }
    
    func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            forceUnlock() // 無効化された瞬間にロック状態を強制リセット
        }
    }
    
    private func postSyntheticMouseUp() {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return }
        guard let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: mouseLocation, mouseButton: .left) else { return }
        
        // 合成されたイベントをタップにキャッチされないようにシステムのイベントキューにポストする
        mouseUpEvent.post(tap: .cghidEventTap)
        print("Synthetic mouse up posted")
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        let service = SMAppService.mainApp
        
        if enabled {
            do {
                try service.register()
                print("Successfully registered launch at login")
            } catch {
                print("Failed to register launch at login: \(error)")
                // 失敗した場合は状態を戻す（UIに反映させるためメインスレッドで実行）
                DispatchQueue.main.async {
                    self.isLaunchAtLoginEnabled = false
                }
            }
        } else {
            // unregister(completionHandler:) は Swift では直接呼び出せないので unregister() を使用
            do {
                try service.unregister()
                print("Successfully unregistered launch at login")
            } catch {
                print("Failed to unregister launch at login: \(error)")
                // 失敗した場合は状態を戻す（UIに反映させるためメインスレッドで実行）
                DispatchQueue.main.async {
                    self.isLaunchAtLoginEnabled = true
                }
            }
        }
    }
}

// C関数としてのコールバック
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<EventManager>.fromOpaque(refcon).takeUnretainedValue()
    
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}
