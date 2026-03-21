import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement
import SwiftUI

enum EventManagerState: Equatable, Sendable {
    case idle
    case holding // マウスダウン中、待機
    case locked  // ロック状態
}

enum MouseButton: Int, CaseIterable, Sendable {
    case left = 0
    case right = 1
    case middle = 2

    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }

    var mouseDownType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .middle: return .otherMouseDown
        }
    }

    var mouseUpType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .middle: return .otherMouseUp
        }
    }

    var mouseDraggedType: CGEventType {
        switch self {
        case .left: return .leftMouseDragged
        case .right: return .rightMouseDragged
        case .middle: return .otherMouseDragged
        }
    }
}

enum IconStyle: String, CaseIterable, Sendable {
    case padlock = "南京錠"
    case dot = "ドット"
    case largeRing = "大きなリング"
}

enum LockType: String, CaseIterable, Sendable {
    case time = "時間"
    case distance = "距離"
    case both = "両方"

    var localizedName: LocalizedStringResource {
        switch self {
        case .time: return LocalizedStringResource("時間", comment: "ドラッグロックの開始条件：クリックし続ける時間によるロック")
        case .distance: return LocalizedStringResource("距離", comment: "ドラッグロックの開始条件：ドラッグした距離によるロック")
        case .both: return LocalizedStringResource("両方", comment: "ドラッグロックの開始条件：時間と距離の両方を有効にする")
        }
    }
}

enum AppListMode: String, CaseIterable, Sendable {
    case exclude = "除外する"
    case include = "含める"

    var localizedName: LocalizedStringResource {
        switch self {
        case .exclude: return LocalizedStringResource("除外する", comment: "アプリフィルタリングのモード：リスト内のアプリをロック対象から外す")
        case .include: return LocalizedStringResource("含める", comment: "アプリフィルタリングのモード：リスト内のアプリのみをロック対象にする")
        }
    }
}

enum ManagedApplicationListEvaluator {
    static func shouldLock(
        bundleIdentifier: String?,
        mode: AppListMode,
        listedBundleIdentifiers: Set<String>
    ) -> Bool {
        switch mode {
        case .exclude:
            guard let bundleIdentifier else { return true }
            return !listedBundleIdentifiers.contains(bundleIdentifier)
        case .include:
            guard let bundleIdentifier else { return false }
            return listedBundleIdentifiers.contains(bundleIdentifier)
        }
    }
}

class EventManager: ObservableObject {
    static let shared = EventManager()

    private let ownPID = ProcessInfo.processInfo.processIdentifier

    @Published var isTrusted: Bool = false
    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var buttonStates: [MouseButton: EventManagerState] = [
        .left: .idle,
        .right: .idle,
        .middle: .idle
    ]

    @Published var isLocked: Bool = false {
        didSet {
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
    private var holdTimers: [MouseButton: Timer] = [:]

    @Published var enabledButtonRawValues: Set<Int> = [0] {
        didSet {
            UserDefaults.standard.set(Array(enabledButtonRawValues), forKey: "enabledButtonRawValues")
        }
    }

    @Published var isSoundEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "isSoundEnabled")
        }
    }

    @Published var soundStyle: SoundStyle = .system {
        didSet {
            UserDefaults.standard.set(soundStyle.rawValue, forKey: "soundStyle")
        }
    }

    @Published var soundVolume: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
        }
    }

    @Published var isSoundInverted: Bool = false {
        didSet {
            UserDefaults.standard.set(isSoundInverted, forKey: "isSoundInverted")
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

    @Published var lockType: LockType = .time {
        didSet {
            UserDefaults.standard.set(lockType.rawValue, forKey: "lockType")
        }
    }

    @Published var lockDistance: Double = 100.0 {
        didSet {
            UserDefaults.standard.set(lockDistance, forKey: "lockDistance")
        }
    }

    @Published var appListMode: AppListMode = .exclude {
        didSet {
            UserDefaults.standard.set(appListMode.rawValue, forKey: "appListMode")
        }
    }

    @Published var managedAppBundleIdentifiers: [String] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(managedAppBundleIdentifiers) {
                UserDefaults.standard.set(encoded, forKey: "managedAppBundleIdentifiersData")
            }
        }
    }

    private var dragStartLocations: [MouseButton: CGPoint] = [:]

    init() {
        // 保存された設定の読み込み
        let savedDelay = UserDefaults.standard.double(forKey: "lockDelay")
        if savedDelay > 0 {
            self.lockDelay = savedDelay
        } else {
            self.lockDelay = 1.0
        }

        if let savedLockTypeRaw = UserDefaults.standard.string(forKey: "lockType"), let type = LockType(rawValue: savedLockTypeRaw) {
            self.lockType = type
        } else {
            self.lockType = .time
        }

        let savedDistance = UserDefaults.standard.double(forKey: "lockDistance")
        self.lockDistance = (savedDistance == 0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains("lockDistance")) ? 100.0 : savedDistance

        if let savedAppListModeRawValue = UserDefaults.standard.string(forKey: "appListMode"),
           let savedAppListMode = AppListMode(rawValue: savedAppListModeRawValue) {
            self.appListMode = savedAppListMode
        } else {
            self.appListMode = .exclude
        }

        if let appListData = UserDefaults.standard.data(forKey: "managedAppBundleIdentifiersData"),
           let decodedAppBundleIdentifiers = try? JSONDecoder().decode([String].self, from: appListData) {
            self.managedAppBundleIdentifiers = decodedAppBundleIdentifiers
        } else {
            self.managedAppBundleIdentifiers = []
        }

        if let savedButtons = UserDefaults.standard.array(forKey: "enabledButtonRawValues") as? [Int] {
            self.enabledButtonRawValues = Set(savedButtons)
        } else {
            self.enabledButtonRawValues = [0]
        }

        self.isSoundEnabled = UserDefaults.standard.bool(forKey: "isSoundEnabled")
        if let savedSoundStyle = UserDefaults.standard.string(forKey: "soundStyle"), let style = SoundStyle(rawValue: savedSoundStyle) {
            self.soundStyle = style
        }
        let savedVolume = UserDefaults.standard.double(forKey: "soundVolume")
        self.soundVolume = (savedVolume == 0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains("soundVolume")) ? 0.5 : savedVolume
        self.isSoundInverted = UserDefaults.standard.bool(forKey: "isSoundInverted")

        self.isIconEnabled = UserDefaults.standard.bool(forKey: "isIconEnabled")
        if let savedStyle = UserDefaults.standard.string(forKey: "pointerIconStyle"), let style = IconStyle(rawValue: savedStyle) {
            self.pointerIconStyle = style
        }
        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled

        // 現在のサウンドをメモリにプリロードして遅延をなくす
        SoundManager.shared.loadSound(style: self.soundStyle)

        if UserDefaults.standard.object(forKey: "isEnabled") == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        }

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
                        (1 << CGEventType.rightMouseDown.rawValue) |
                        (1 << CGEventType.rightMouseUp.rawValue) |
                        (1 << CGEventType.rightMouseDragged.rawValue) |
                        (1 << CGEventType.otherMouseDown.rawValue) |
                        (1 << CGEventType.otherMouseUp.rawValue) |
                        (1 << CGEventType.otherMouseDragged.rawValue) |
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

    // マウス座標にあるアプリがDragLocker自身かどうかを判定する
    private func isEventTargetingOwnApp(event: CGEvent) -> Bool {
        let mouseLocation = event.location
        guard let targetPID = windowOwnerPID(at: mouseLocation) else {
            return false
        }

        return targetPID == ownPID
    }

    private func windowOwnerPID(at location: CGPoint) -> pid_t? {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            if !bounds.contains(location) {
                continue
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            let alpha = windowInfo[kCGWindowAlpha as String] as? Double ?? 1.0
            if layer == 0 && alpha > 0 {
                return pid_t(windowPID)
            }
        }

        return nil
    }

    private func bundleIdentifierForApplication(at location: CGPoint) -> String? {
        guard let targetPID = windowOwnerPID(at: location) else {
            return nil
        }

        return NSRunningApplication(processIdentifier: targetPID)?.bundleIdentifier
    }

    private func shouldLock(at location: CGPoint) -> Bool {
        let listedBundleIdentifiers = Set(managedAppBundleIdentifiers)
        let targetBundleIdentifier = bundleIdentifierForApplication(at: location)
        let shouldLock = ManagedApplicationListEvaluator.shouldLock(
            bundleIdentifier: targetBundleIdentifier,
            mode: appListMode,
            listedBundleIdentifiers: listedBundleIdentifiers
        )

        print("App filter check at \(location): bundleIdentifier=\(targetBundleIdentifier ?? "none"), mode=\(appListMode.rawValue), shouldLock=\(shouldLock)")
        return shouldLock
    }

    func addManagedApp(bundleIdentifier: String) {
        guard !managedAppBundleIdentifiers.contains(bundleIdentifier) else {
            print("Managed app already exists: \(bundleIdentifier)")
            return
        }

        managedAppBundleIdentifiers.append(bundleIdentifier)
        print("Managed app added: \(bundleIdentifier)")
    }

    func removeManagedApp(bundleIdentifier: String) {
        managedAppBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        print("Managed app removed: \(bundleIdentifier)")
    }

    func clearManagedApps() {
        managedAppBundleIdentifiers = []
        print("Managed app list cleared")
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
                print("Escape pressed: Releasing all locks")
                releaseAllLocks()
            }
            return Unmanaged.passRetained(event) // キーボードイベントはそのまま通す
        }

        // 各ボタンのイベント判定
        for button in MouseButton.allCases {
            // このボタンが有効設定になっていない場合はスキップ
            if !enabledButtonRawValues.contains(button.rawValue) {
                continue
            }

            if type == button.mouseDownType {
                // 中ボタン(OtherMouse)の場合は、ボタン番号が正しいかチェック
                if type == .otherMouseDown {
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber != 2 { continue } // 2が中ボタン
                }

                // DragLockerアプリ自身へのクリックではロック機能を発動しない
                if isEventTargetingOwnApp(event: event) {
                    print("\(button) down: Targeting own app, ignoring")
                    if buttonStates[button] == .locked {
                        releaseLock(for: button)
                    } else if buttonStates[button] == .holding {
                        cancelHold(for: button)
                    }
                    return Unmanaged.passRetained(event)
                }

                if !shouldLock(at: event.location) {
                    print("\(button) down: Current app is filtered out")
                    if buttonStates[button] == .holding {
                        cancelHold(for: button)
                    }
                    return Unmanaged.passRetained(event)
                }

                if buttonStates[button] == .idle {
                    print("\(button) down: Starting tracking")
                    updateButtonState(button, to: .holding)
                    dragStartLocations[button] = event.location
                    
                    if lockType == .time || lockType == .both {
                        DispatchQueue.main.async {
                            self.startTimer(for: button)
                        }
                    }
                } else if buttonStates[button] == .locked {
                    print("\(button) down while locked: Releasing lock")
                    releaseLock(for: button)
                }
                return Unmanaged.passRetained(event)
            }

            if type == button.mouseUpType {
                if type == .otherMouseUp {
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber != 2 { continue }
                }

                if buttonStates[button] == .holding {
                    print("\(button) up: Normal click, canceling timer")
                    cancelHold(for: button)
                    return Unmanaged.passRetained(event)
                } else if buttonStates[button] == .locked {
                    print("\(button) up while locked: Ignoring to keep the lock")
                    return nil
                }
            }
        }

        // ドラッグイベントの処理
        if type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged || type == .mouseMoved {
            // 自動ロック判定（ドラッグ中かつ未ロックの場合）
            if (lockType == .distance || lockType == .both) && !isLocked {
                for button in MouseButton.allCases {
                    if buttonStates[button] == .holding, let startLocation = dragStartLocations[button] {
                        let currentLocation = event.location
                        let distance = sqrt(pow(currentLocation.x - startLocation.x, 2) + pow(currentLocation.y - startLocation.y, 2))
                        
                        if distance >= lockDistance && shouldLock(at: currentLocation) {
                            print("\(button) distance (\(distance)) exceeded threshold (\(lockDistance)): Locking")
                            updateButtonState(button, to: .locked)
                            break
                        }
                    }
                }
            }

            // いずれかのボタンがロック中なら、カスタムカーソルの位置を更新
            if isLocked {
                DispatchQueue.main.async {
                    CursorManager.shared.updatePosition()
                }

                // mouseMoved（物理ボタンが押されていない状態での移動）をドラッグに変換
                if type == .mouseMoved {
                    // 現在ロック中のボタンのうち、最初に見つかったもののドラッグタイプを使用
                    if let lockedButton = MouseButton.allCases.first(where: { buttonStates[$0] == .locked }) {
                        event.type = lockedButton.mouseDraggedType
                        if lockedButton == .middle {
                            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
                        }
                    }
                }
                return Unmanaged.passRetained(event)
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func updateButtonState(_ button: MouseButton, to newState: EventManagerState) {
        let oldState = buttonStates[button]
        buttonStates[button] = newState

        // グローバルのロック状態を更新
        let anyLocked = buttonStates.values.contains(.locked)
        DispatchQueue.main.async {
            self.isLocked = anyLocked
        }

        // サウンド再生の判定
        if isSoundEnabled {
            if oldState != .locked && newState == .locked {
                // ロックされた
                SoundManager.shared.play(style: soundStyle, volume: soundVolume, isLocked: true, isInverted: isSoundInverted)
            } else if oldState == .locked && newState != .locked {
                // 解除された
                SoundManager.shared.play(style: soundStyle, volume: soundVolume, isLocked: false, isInverted: isSoundInverted)
            }
        }
    }

    private func startTimer(for button: MouseButton) {
        holdTimers[button]?.invalidate()
        let timer = Timer(timeInterval: lockDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.buttonStates[button] == .holding {
                    guard self.shouldLock(at: NSEvent.mouseLocation) else {
                        print("Timer fired: \(button) Current app is filtered out")
                        self.cancelHold(for: button)
                        return
                    }
                    print("Timer fired: \(button) Lock active!")
                    self.updateButtonState(button, to: .locked)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimers[button] = timer
    }

    private func cancelHold(for button: MouseButton) {
        updateButtonState(button, to: .idle)
        dragStartLocations[button] = nil
        DispatchQueue.main.async {
            self.holdTimers[button]?.invalidate()
            self.holdTimers[button] = nil
        }
    }

    private func releaseLock(for button: MouseButton) {
        updateButtonState(button, to: .idle)
        dragStartLocations[button] = nil
        postSyntheticMouseUp(for: button)
    }

    private func releaseAllLocks() {
        for button in MouseButton.allCases {
            if buttonStates[button] == .locked {
                releaseLock(for: button)
            } else if buttonStates[button] == .holding {
                cancelHold(for: button)
            }
        }
    }

    func forceUnlock() {
        releaseAllLocks()
    }

    func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            forceUnlock()
        }
    }

    private func postSyntheticMouseUp(for button: MouseButton) {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return }

        let mouseUpEvent: CGEvent?
        if button == .middle {
            mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: mouseLocation, mouseButton: .center)
            mouseUpEvent?.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        } else {
            mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: button.mouseUpType, mouseCursorPosition: mouseLocation, mouseButton: button.cgButton)
        }

        mouseUpEvent?.post(tap: .cghidEventTap)
        print("Synthetic \(button) mouse up posted")
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        let service = SMAppService.mainApp
        
        if enabled {
            do {
                try service.register()
                print("Successfully registered launch at login")
            } catch {
                print("Failed to register launch at login: \(error)")
                DispatchQueue.main.async {
                    self.isLaunchAtLoginEnabled = false
                }
            }
        } else {
            do {
                try service.unregister()
                print("Successfully unregistered launch at login")
            } catch {
                print("Failed to unregister launch at login: \(error)")
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
