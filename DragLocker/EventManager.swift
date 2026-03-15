import AppKit
import Combine
import CoreGraphics
import Foundation

enum EventManagerState: Equatable {
    case idle
    case holding // マウスダウン中、待機
    case locked  // ロック状態
}

class EventManager: ObservableObject {
    static let shared = EventManager()
    
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
    
    @Published var isLocked: Bool = false
    private var holdTimer: Timer?
    
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
    }
    
    func start() {
        checkAccessibilityPermissions()
    }
    
    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.async {
            self.isTrusted = accessEnabled
            if self.isTrusted {
                self.setupEventTap()
            }
        }
    }
    
    func requestAccessibilityPermissions() {
        // Here we pass true to force the system to prompt if permissions are missing
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.async {
            self.isTrusted = accessEnabled
            if self.isTrusted {
                self.setupEventTap()
            }
        }
    }
    
    private func setupEventTap() {
        guard isTrusted else { return }
        if eventTap != nil { return }
        
        // 監視するイベント
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.leftMouseUp.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)
        
        // Cのコールバック関数に self を渡すため、Unmanaged を使用
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
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
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Event tap successfully set up")
        }
    }
    
    // イベント処理のエントリーポイント
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
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
        holdTimer = Timer.scheduledTimer(withTimeInterval: lockDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.state == .holding {
                print("Timer fired: Lock active!")
                self.state = .locked
                // 後でここに触覚フィードバック（Haptic feedback）などを追加できます
            }
        }
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
}

// C関数としてのコールバック
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<EventManager>.fromOpaque(refcon).takeUnretainedValue()
    
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}
