import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement
import SwiftUI
import KeyboardShortcuts
import UserNotifications
import AVFoundation
import CoreMedia

extension KeyboardShortcuts.Name {
    static let toggleMonitoring = Self("toggleMonitoring")
}

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

enum IconAnimation: String, CaseIterable, Sendable {
    case `default` = "default"
    case none = "none"
    case fade = "fade"
    case scale = "scale"
    case pop = "pop"
    case popPlus = "popPlus"
    case focus = "focus"
    case focusPlus = "focusPlus"

    var localizedName: LocalizedStringResource {
        switch self {
        case .default: return LocalizedStringResource("デフォルト", comment: "アイコンアニメーション：各アイコンのデフォルト設定")
        case .none: return LocalizedStringResource("なし", comment: "アイコンアニメーション：アニメーションなし")
        case .fade: return LocalizedStringResource("フェード", comment: "アイコンアニメーション：不透明度の変化")
        case .scale: return LocalizedStringResource("スケール", comment: "アイコンアニメーション：拡大縮小しながら表示・非表示（0.1秒）")
        case .pop: return LocalizedStringResource("ポップ", comment: "アイコンアニメーション：拡大縮小しながら表示・非表示")
        case .popPlus: return LocalizedStringResource("ポップ+", comment: "アイコンアニメーション：より強調されたポップ")
        case .focus: return LocalizedStringResource("フォーカス", comment: "アイコンアニメーション：フォーカスアイコン用のアニメーション")
        case .focusPlus: return LocalizedStringResource("フォーカス+", comment: "アイコンアニメーション：より強調されたフォーカス")
        }
    }
}

enum IconStyle: String, CaseIterable, Sendable {
    case padlock = "padlock"
    case dot = "dot"
    case largeRing = "large_ring"
    case focus = "focus"
    case trafficLight = "traffic_light"
    case smallTrafficLight = "small_traffic_light"
    case trafficLightVertical = "traffic_light_vertical"
    case smallTrafficLightVertical = "small_traffic_light_vertical"
    case textHorizontal = "text_horizontal"
    case textVertical = "text_vertical"
    case custom = "custom"

    var localizedName: LocalizedStringResource {
        switch self {
        case .padlock: return LocalizedStringResource("南京錠", comment: "ポインタ付近に表示するアイコンの種類：鍵")
        case .dot: return LocalizedStringResource("ドット", comment: "ポインタ付近に表示するアイコンの種類：点")
        case .largeRing: return LocalizedStringResource("大きなリング", comment: "ポインタ付近に表示するアイコンの種類：大きな円")
        case .focus: return LocalizedStringResource("フォーカス", comment: "ポインタ付近に表示するアイコンの種類：カメラのファインダーのような角括弧")
        case .trafficLight: return LocalizedStringResource("信号機（横）", comment: "アイコンスタイル：ボタンごとのロックを表示する信号機スタイル")
        case .smallTrafficLight: return LocalizedStringResource("小さな信号機（横）", comment: "アイコンスタイル：信号機スタイルの縮小版")
        case .trafficLightVertical: return LocalizedStringResource("信号機（縦）", comment: "アイコンスタイル：ボタンごとのロックを垂直に表示する信号機スタイル")
        case .smallTrafficLightVertical: return LocalizedStringResource("小さな信号機（縦）", comment: "アイコンスタイル：垂直信号機スタイルの縮小版")
        case .textHorizontal: return LocalizedStringResource("テキスト（横）", comment: "ポインタ付近に表示するアイコンの種類：テキスト（横）")
        case .textVertical: return LocalizedStringResource("テキスト（縦）", comment: "ポインタ付近に表示するアイコンの種類：テキスト（縦）")
        case .custom: return LocalizedStringResource("カスタム", comment: "ポインタ付近に表示するアイコンの種類：カスタム画像")
        }
    }

    var defaultXOffset: Double {
        switch self {
        case .padlock: return 12.0
        case .dot: return 12.0
        case .largeRing: return -25.0
        case .focus: return -25.0
        case .trafficLight: return 12.0
        case .smallTrafficLight: return 12.0
        case .trafficLightVertical: return 14.0
        case .smallTrafficLightVertical: return 14.0
        case .textHorizontal: return 12.0
        case .textVertical: return 13.0
        case .custom: return 0.0
        }
    }
    
    var defaultYOffset: Double {
        switch self {
        case .padlock: return -7.0
        case .dot: return -4.0
        case .largeRing: return -24.0
        case .focus: return -24.0
        case .trafficLight: return -6.5
        case .smallTrafficLight: return -4.5
        case .trafficLightVertical: return -17.5
        case .smallTrafficLightVertical: return -12.0
        case .textHorizontal: return -8.0
        case .textVertical: return -14.0
        case .custom: return 0.0
        }
    }
    
    var defaultScale: Double {
        return 1.0
    }
    
    var defaultOpacity: Double {
        return 1.0
    }
}

enum LockType: String, CaseIterable, Sendable {
    case time = "time"
    case distance = "distance"
    case both = "both"

    var localizedName: LocalizedStringResource {
        switch self {
        case .time: return LocalizedStringResource("時間", comment: "ドラッグロックの開始条件：クリックし続ける時間によるロック")
        case .distance: return LocalizedStringResource("距離", comment: "ドラッグロックの開始条件：ドラッグした距離によるロック")
        case .both: return LocalizedStringResource("両方", comment: "ドラッグロックの開始条件：時間と距離の両方を有効にする")
        }
    }
}

enum AppListMode: String, CaseIterable, Sendable {
    case exclude = "exclude"
    case include = "include"

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
        executableName: String?,
        executablePath: String?,
        mode: AppListMode,
        listedIdentifiers: Set<String>
    ) -> Bool {
        let isMatch: Bool
        if let bundleIdentifier = bundleIdentifier, listedIdentifiers.contains(bundleIdentifier) {
            isMatch = true
        } else if let executableName = executableName, listedIdentifiers.contains(executableName) {
            isMatch = true
        } else if let executablePath = executablePath, listedIdentifiers.contains(executablePath) {
            isMatch = true
        } else {
            isMatch = false
        }

        switch mode {
        case .exclude:
            return !isMatch
        case .include:
            return isMatch
        }
    }
}

class EventManager: NSObject, ObservableObject {
    static let shared = EventManager()
    
    // パフォーマンス向上のためのSetキャッシュ
    private var managedAppBundleIdentifiersSet: Set<String> = []

    @Published var isTrusted: Bool = false
    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            if isNotificationEnabled && !isProcessingNotificationAction {
                sendToggleNotification(isEnabled: isEnabled)
            }
            // 無効化された際にすべてのロックを解除する
            if !isEnabled {
                forceUnlock()
            }
        }
    }

    @Published var isNotificationEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isNotificationEnabled, forKey: "isNotificationEnabled")
            if isNotificationEnabled && !isNotificationTrusted {
                requestNotificationPermissions()
            }
        }
    }

    @Published var isNotificationTrusted: Bool = false

    private let resumeActionIdentifier = "RESUME_ACTION"
    private let monitoringCategoryIdentifier = "MONITORING_CATEGORY"

    private var isProcessingNotificationAction: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var iconSettings: [String: Double] = [:]
    private var isInitializing = false

    private var buttonStates: [MouseButton: EventManagerState] = [
        .left: .idle,
        .right: .idle,
        .middle: .idle
    ]

    var isLocked: Bool = false {
        didSet {
            DispatchQueue.main.async {
                LockStateManager.shared.isLocked = self.isLocked
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
    var lockedButtons: Set<MouseButton> = [] {
        didSet {
            DispatchQueue.main.async {
                LockStateManager.shared.lockedButtons = self.lockedButtons
            }
        }
    }
    private var holdTimers: [MouseButton: Timer] = [:]

    @Published var enabledButtonRawValues: Set<Int> = [0] {
        didSet {
            UserDefaults.standard.set(Array(enabledButtonRawValues), forKey: "enabledButtonRawValues")
            
            // 対象外になったボタンのロックを解除する
            let removedValues = oldValue.subtracting(enabledButtonRawValues)
            for rawValue in removedValues {
                if let button = MouseButton(rawValue: rawValue) {
                    if buttonStates[button] == .locked {
                        #if DEBUG
                        print("\(button) was removed from target buttons: Releasing lock")
                        #endif
                        releaseLock(for: button)
                    } else if buttonStates[button] == .holding {
                        #if DEBUG
                        print("\(button) was removed from target buttons: Canceling hold")
                        #endif
                        cancelHold(for: button)
                    }
                }
            }
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

    @Published var customSound1Path: String? {
        didSet {
            UserDefaults.standard.set(customSound1Path, forKey: "customSound1Path")
        }
    }

    @Published var customSound1Name: String? {
        didSet {
            UserDefaults.standard.set(customSound1Name, forKey: "customSound1Name")
        }
    }

    @Published var customSound2Path: String? {
        didSet {
            UserDefaults.standard.set(customSound2Path, forKey: "customSound2Path")
        }
    }

    @Published var customSound2Name: String? {
        didSet {
            UserDefaults.standard.set(customSound2Name, forKey: "customSound2Name")
        }
    }

    @Published var customIconPath: String? {
        didSet {
            UserDefaults.standard.set(customIconPath, forKey: "customIconPath")
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
        }
    }
    
    @Published var customIconName: String? {
        didSet {
            UserDefaults.standard.set(customIconName, forKey: "customIconName")
        }
    }

    @Published var customIconScale: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(customIconScale, forKey: "customIconScale")
            saveCurrentIconSettings()
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
        }
    }

    @Published var customIconXOffset: Double = 0.0 {
        didSet {
            UserDefaults.standard.set(customIconXOffset, forKey: "customIconXOffset")
            saveCurrentIconSettings()
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
        }
    }

    @Published var customIconYOffset: Double = 0.0 {
        didSet {
            UserDefaults.standard.set(customIconYOffset, forKey: "customIconYOffset")
            saveCurrentIconSettings()
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
        }
    }

    @Published var customIconOpacity: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(customIconOpacity, forKey: "customIconOpacity")
            saveCurrentIconSettings()
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
        }
    }

    @Published var iconAnimation: IconAnimation = .default {
        didSet {
            UserDefaults.standard.set(iconAnimation.rawValue, forKey: "iconAnimation")
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
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
        willSet {
            saveCurrentIconSettings()
        }
        didSet {
            UserDefaults.standard.set(pointerIconStyle.rawValue, forKey: "pointerIconStyle")
            // スタイル変更時にロード（初期化中以外かつカスタム以外ならリセット）
            loadIconSettings(for: pointerIconStyle, resetToDefaults: !isInitializing && pointerIconStyle != .custom)
            DispatchQueue.main.async {
                CursorManager.shared.updateCursorStyle()
            }
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

    @Published var isIgnoreSystemOverlaysEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isIgnoreSystemOverlaysEnabled, forKey: "isIgnoreSystemOverlaysEnabled")
        }
    }

    @Published var isUnlockAllWithEscEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isUnlockAllWithEscEnabled, forKey: "isUnlockAllWithEscEnabled")
        }
    }

    @Published var managedAppBundleIdentifiers: [String] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(managedAppBundleIdentifiers) {
                UserDefaults.standard.set(encoded, forKey: "managedAppBundleIdentifiersData")
            }
            // 配列が更新されたらSetのキャッシュも更新する
            managedAppBundleIdentifiersSet = Set(managedAppBundleIdentifiers)
        }
    }

    private var dragStartLocations: [MouseButton: CGPoint] = [:]
    private var lastLocation: CGPoint = .zero

    // アプリケーション確認のキャッシュ（メモリ負荷軽減とリーク防止）
    private var lastAppCheckTime: Date = .distantPast
    private var lastAppCheckLocation: CGPoint = .zero
    private var lastAppBundleIdentifier: String?
    private var lastAppExecutableName: String?
    private var lastAppExecutablePath: String?
    private var lastAppIsOverlay: Bool = false

    // ウィンドウリストのキャッシュ（高頻度な呼び出しによるメモリ負荷を軽減）
    private var lastWindowList: [[String: Any]]?
    private var lastWindowListTime: Date = .distantPast

    override init() {
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

        self.isIgnoreSystemOverlaysEnabled = UserDefaults.standard.bool(forKey: "isIgnoreSystemOverlaysEnabled")

        if UserDefaults.standard.object(forKey: "isUnlockAllWithEscEnabled") == nil {
            self.isUnlockAllWithEscEnabled = true
        } else {
            self.isUnlockAllWithEscEnabled = UserDefaults.standard.bool(forKey: "isUnlockAllWithEscEnabled")
        }

        if let appListData = UserDefaults.standard.data(forKey: "managedAppBundleIdentifiersData"),
           let decodedAppBundleIdentifiers = try? JSONDecoder().decode([String].self, from: appListData) {
            self.managedAppBundleIdentifiers = decodedAppBundleIdentifiers
            self.managedAppBundleIdentifiersSet = Set(decodedAppBundleIdentifiers)
        } else {
            self.managedAppBundleIdentifiers = []
            self.managedAppBundleIdentifiersSet = []
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

        self.customSound1Path = UserDefaults.standard.string(forKey: "customSound1Path")
        self.customSound1Name = UserDefaults.standard.string(forKey: "customSound1Name")
        self.customSound2Path = UserDefaults.standard.string(forKey: "customSound2Path")
        self.customSound2Name = UserDefaults.standard.string(forKey: "customSound2Name")

        self.customIconPath = UserDefaults.standard.string(forKey: "customIconPath")
        self.customIconName = UserDefaults.standard.string(forKey: "customIconName")
        if let savedScale = UserDefaults.standard.object(forKey: "customIconScale") as? Double {
            self.customIconScale = savedScale
        }
        if let savedXOffset = UserDefaults.standard.object(forKey: "customIconXOffset") as? Double {
            self.customIconXOffset = savedXOffset
        }
        if let savedYOffset = UserDefaults.standard.object(forKey: "customIconYOffset") as? Double {
            self.customIconYOffset = savedYOffset
        }
        if let savedOpacity = UserDefaults.standard.object(forKey: "customIconOpacity") as? Double {
            self.customIconOpacity = savedOpacity
        } else {
            self.customIconOpacity = 1.0
        }

        self.isIconEnabled = UserDefaults.standard.bool(forKey: "isIconEnabled")
        if let savedAnimationRaw = UserDefaults.standard.string(forKey: "iconAnimation"), let animation = IconAnimation(rawValue: savedAnimationRaw) {
            self.iconAnimation = animation
        } else {
            self.iconAnimation = .default
        }

        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled

        // 各アイコンの設定をロード
        if let savedIconSettings = UserDefaults.standard.dictionary(forKey: "allIconSettings") as? [String: Double] {
            self.iconSettings = savedIconSettings
        }
        
        self.isNotificationEnabled = UserDefaults.standard.bool(forKey: "isNotificationEnabled")

        isInitializing = true
        super.init()

        if let savedStyle = UserDefaults.standard.string(forKey: "pointerIconStyle"), let style = IconStyle(rawValue: savedStyle) {
            self.pointerIconStyle = style
        }
        
        // 現在のスタイルの設定を反映（初期ロード時はリセットしない）
        loadIconSettings(for: self.pointerIconStyle, resetToDefaults: false)
        isInitializing = false

        // 通知センターの設定
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        checkNotificationPermissions()

        // 現在のサウンドをメモリにプリロードして遅延をなくす
        SoundManager.shared.loadSound(style: self.soundStyle)

        if UserDefaults.standard.object(forKey: "isEnabled") == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        }

        // ショートカットが未設定の場合は、デフォルト（⌘ + ⌃ + ⇧ + L）をセット
        if KeyboardShortcuts.getShortcut(for: .toggleMonitoring) == nil {
            KeyboardShortcuts.setShortcut(.init(.l, modifiers: [.command, .control, .shift]), for: .toggleMonitoring)
        }

        // ショートカットのイベントリスナーを登録
        KeyboardShortcuts.onKeyUp(for: .toggleMonitoring) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleEnabled()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPermissions),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // 起動時に停止状態なら通知を送る
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendInitialPausedNotification()
        }

        // システムイベントの監視（スリープ、画面ロック、ユーザ切り替え時にロックを解除する）
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemEvent),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemEvent),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemEvent),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
    }

    @objc private func handleSystemEvent() {
        #if DEBUG
        print("System event detected (Sleep/Lock/UserSwitch): Releasing all locks for safety")
        #endif
        DispatchQueue.main.async {
            self.forceUnlock()
        }
    }

    func start() {
        refreshPermissions()
    }

    @objc private func refreshPermissions() {
        checkAccessibilityPermissions()
        checkNotificationPermissions()
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

    @objc func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            print("Checking Notification Permissions: \(isAuthorized)")
            DispatchQueue.main.async {
                self.isNotificationTrusted = isAuthorized
            }
        }
    }

    private func setupNotificationCategories() {
        let resumeAction = UNNotificationAction(
            identifier: resumeActionIdentifier,
            title: String(localized: "再開"),
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: monitoringCategoryIdentifier,
            actions: [resumeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestNotificationPermissions() {
        print("Requesting Notification Permissions...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("Notification Permission granted: \(granted)")
            if let error = error {
                print("Notification Permission error: \(error)")
            }
            DispatchQueue.main.async {
                self.isNotificationTrusted = granted
            }
        }
    }

    private func sendToggleNotification(isEnabled: Bool) {
        guard isNotificationTrusted else { return }

        let content = UNMutableNotificationContent()
        if isEnabled {
            content.title = String(localized: "ドラッグロック オン")
            content.body = String(localized: "ドラッグロックが再開しました。")
        } else {
            content.title = String(localized: "ドラッグロック オフ")
            content.body = String(localized: "ドラッグロックが一時停止状態になりました。再びドラッグロックしたい場合は再開する必要があります。")
            content.categoryIdentifier = monitoringCategoryIdentifier
        }
        
        let request = UNNotificationRequest(
            identifier: "DragLockerToggleNotification",
            content: content,
            trigger: nil // 即時送信
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send toggle notification: \(error)")
            }
        }
    }

    private func sendInitialPausedNotification() {
        guard !isEnabled && isNotificationTrusted && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "ドラッグロックは一時停止状態です")
        content.body = String(localized: "ドラッグロックを有効化するには再開する必要があります。")
        content.categoryIdentifier = monitoringCategoryIdentifier
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "DragLockerInitialPausedNotification",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send initial paused notification: \(error)")
            }
        }
    }

    func sendTestNotification() {
        guard isNotificationTrusted else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "通知のテスト")
        content.body = String(localized: "これは通知のテストです。")
        
        let request = UNNotificationRequest(
            identifier: "DragLockerTestNotification",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error)")
            } else {
                // テスト通知は5秒後に自動で削除する
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["DragLockerTestNotification"])
                }
            }
        }
    }

    func openNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.taikun.DragLocker"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleID)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
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

    private func windowOwnerPID(at location: CGPoint) -> (pid: pid_t, isOverlay: Bool)? {
        return autoreleasepool {
            let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            
            var bestAppPID: pid_t? = nil
            var bestAppLayer: Int = -1
            
            var bestOverlayPID: pid_t? = nil
            var bestOverlayLayer: Int = -1
            
            for windowInfo in windowList {
                guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                      let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                    continue
                }
                
                if bounds.contains(location) {
                    let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
                    let alpha = windowInfo[kCGWindowAlpha as String] as? Double ?? 1.0
                    let ownerName = windowInfo[kCGWindowOwnerName as String] as? String
                    let windowName = windowInfo[kCGWindowName as String] as? String
                    
                    // デバッグ用: 座標も一緒に出力
                    #if DEBUG
                    print("[Debug] Window at \(location): owner='\(ownerName ?? "n/a")', layer=\(layer), alpha=\(alpha), name='\(windowName ?? "n/a")'")
                    #endif
                    
                    let pid = pid_t(windowPID)
                    
                    // 1. 通常のアプリ (layer 0〜19)
                    // 最前面のアプリ (layer 3) など、Dockアイコンのないものも含めて捕捉
                    if layer < 20 && ownerName != "Dock" && ownerName != "AssistiveControl" {
                        if bestAppPID == nil || layer > bestAppLayer {
                            bestAppPID = pid
                            bestAppLayer = layer
                        }
                        continue
                    }
                    
                    // 2. システムオーバーレイ (layer 21〜1999)
                    // 20: Dock背景 は無視する
                    // 2000以上: AssistiveControlの管理用オーバーレイ などは無視する
                    if layer >= 21 && layer < 2000 {
                        // Launchpad(27, 29), メニューバー(24, 25), 通知(23), キーボード(101)など
                        if bestOverlayPID == nil || layer > bestOverlayLayer {
                            bestOverlayPID = pid
                            bestOverlayLayer = layer
                        }
                    }
                }
            }
            
            if let opid = bestOverlayPID {
                return (opid, true)
            }
            if let apid = bestAppPID {
                return (apid, false)
            }
            return nil
        }
    }

    private func appIdentityForApplication(at location: CGPoint) -> (identifier: String?, executableName: String?, executablePath: String?, isOverlay: Bool) {
        let dx = location.x - lastAppCheckLocation.x
        let dy = location.y - lastAppCheckLocation.y
        let distanceSquared = dx * dx + dy * dy
        
        if distanceSquared < 4.0 {
            if Date().timeIntervalSince(lastAppCheckTime) < 0.5 {
                return (lastAppBundleIdentifier, lastAppExecutableName, lastAppExecutablePath, lastAppIsOverlay)
            }
        }

        let result = autoreleasepool { () -> (identifier: String?, executableName: String?, executablePath: String?, isOverlay: Bool) in
            guard let target = windowOwnerPID(at: location) else {
                return (nil, nil, nil, false)
            }

            let runningApp = NSRunningApplication(processIdentifier: target.pid)
            let identifier = runningApp?.bundleIdentifier
            let executableURL = runningApp?.executableURL
            let executableName = executableURL?.lastPathComponent
            let executablePath = executableURL?.path
            return (identifier, executableName, executablePath, target.isOverlay)
        }
        
        lastAppCheckTime = Date()
        lastAppCheckLocation = location
        lastAppBundleIdentifier = result.identifier
        lastAppExecutableName = result.executableName
        lastAppExecutablePath = result.executablePath
        lastAppIsOverlay = result.isOverlay
        
        return result
    }

    private func shouldLock(at location: CGPoint) -> Bool {
        let result = appIdentityForApplication(at: location)
        
        // システムオーバーレイを無視する設定がオンの場合、オーバーレイ上ではロックしない
        if isIgnoreSystemOverlaysEnabled && result.isOverlay {
            #if DEBUG
            print("App filter check at \(location): System overlay ignored (bundleId=\(result.identifier ?? "unknown"), exe=\(result.executableName ?? "unknown"), path=\(result.executablePath ?? "unknown"))")
            #endif
            return false
        }
        
        let shouldLock = ManagedApplicationListEvaluator.shouldLock(
            bundleIdentifier: result.identifier,
            executableName: result.executableName,
            executablePath: result.executablePath,
            mode: appListMode,
            listedIdentifiers: managedAppBundleIdentifiersSet
        )

        #if DEBUG
        print("App filter check at \(location): bundleIdentifier=\(result.identifier ?? "none"), executableName=\(result.executableName ?? "none"), executablePath=\(result.executablePath ?? "none"), mode=\(appListMode.rawValue), shouldLock=\(shouldLock)")
        #endif
        return shouldLock
    }

    func addManagedApp(bundleIdentifier: String) {
        guard !managedAppBundleIdentifiers.contains(bundleIdentifier) else {
            #if DEBUG
            print("Managed app already exists: \(bundleIdentifier)")
            #endif
            return
        }

        managedAppBundleIdentifiers.append(bundleIdentifier)
        #if DEBUG
        print("Managed app added: \(bundleIdentifier)")
        #endif
    }

    func removeManagedApp(bundleIdentifier: String) {
        managedAppBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        #if DEBUG
        print("Managed app removed: \(bundleIdentifier)")
        #endif
    }

    func clearManagedApps() {
        managedAppBundleIdentifiers = []
        #if DEBUG
        print("Managed app list cleared")
        #endif
    }

    // MARK: - Custom Sound Management

    private var appSupportDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DragLocker", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir
    }

    private var customSoundsDirectory: URL {
        let customSoundsDir = appSupportDirectory.appendingPathComponent("CustomSounds", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: customSoundsDir.path) {
            try? FileManager.default.createDirectory(at: customSoundsDir, withIntermediateDirectories: true)
        }
        
        return customSoundsDir
    }

    private var customIconsDirectory: URL {
        let customIconsDir = appSupportDirectory.appendingPathComponent("CustomIcons", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: customIconsDir.path) {
            try? FileManager.default.createDirectory(at: customIconsDir, withIntermediateDirectories: true)
        }
        
        return customIconsDir
    }

    func saveCustomIcon(url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        let fileExtension = url.pathExtension
        let originalNameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let fileName = "\(originalNameWithoutExtension)_icon_\(UUID().uuidString).\(fileExtension)"
        let destinationURL = customIconsDirectory.appendingPathComponent(fileName)
        
        deleteCustomIcon()
        try FileManager.default.copyItem(at: url, to: destinationURL)
        
        DispatchQueue.main.async {
            self.customIconPath = destinationURL.path
            self.customIconName = originalNameWithoutExtension
        }
    }

    func deleteCustomIcon() {
        if let currentPath = customIconPath {
            try? FileManager.default.removeItem(atPath: currentPath)
            DispatchQueue.main.async {
                self.customIconPath = nil
                self.customIconName = nil
            }
        }
    }

    func saveCustomSound(url: URL, index: Int) async throws {
        // セキュリティスコープのアクセスを開始（ファイルピッカーから取得したURL用）
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        // ファイルの長さをチェック
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        if seconds > 10.0 {
            throw NSError(domain: "DragLocker", code: 1, userInfo: [NSLocalizedDescriptionKey: "音声が長すぎます。最大10秒までのオーディオファイルを設定することができます。"])
        }
        
        let fileExtension = url.pathExtension
        let originalNameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let fileName = "\(originalNameWithoutExtension)_sound_\(index)_\(UUID().uuidString).\(fileExtension)"
        let destinationURL = customSoundsDirectory.appendingPathComponent(fileName)
        
        // 古いファイルを削除
        deleteCustomSound(index: index)
        
        // 新しいファイルをコピー
        try FileManager.default.copyItem(at: url, to: destinationURL)
        
        DispatchQueue.main.async {
            if index == 1 {
                self.customSound1Path = fileName
                self.customSound1Name = originalNameWithoutExtension
            } else {
                self.customSound2Path = fileName
                self.customSound2Name = originalNameWithoutExtension
            }
            // プリロード
            SoundManager.shared.loadSound(style: .custom)
        }
    }

    func deleteCustomSound(index: Int) {
        let fileName = index == 1 ? customSound1Path : customSound2Path
        if let fileName = fileName {
            let fileURL = customSoundsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        DispatchQueue.main.async {
            if index == 1 {
                self.customSound1Path = nil
                self.customSound1Name = nil
            } else {
                self.customSound2Path = nil
                self.customSound2Name = nil
            }
            // プリロード情報を更新
            SoundManager.shared.loadSound(style: .custom)
        }
    }

    func getCustomSoundURL(index: Int) -> URL? {
        let fileName = index == 1 ? customSound1Path : customSound2Path
        guard let fileName = fileName else { return nil }
        return customSoundsDirectory.appendingPathComponent(fileName)
    }

    // イベント処理のエントリーポイント
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {

        // macOSがタイムアウト等でイベントタップを無効化した場合、再有効化する
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("Event tap was disabled by system, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // アプリケーション機能が一時停止中の場合は何も処理せずイベントを流す
        guard isEnabled else { return Unmanaged.passUnretained(event) }

        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53 /* Escape key */ {
                if isUnlockAllWithEscEnabled {
                    #if DEBUG
                    print("Escape pressed: Releasing all locks")
                    #endif
                    releaseAllLocks()
                }
            }
            return Unmanaged.passUnretained(event) // キーボードイベントはそのまま通す
        }

        // 各ボタンのイベント判定
        let currentLocation = event.location

        // マウスダウン・アップの処理
        for button in MouseButton.allCases {
            if !enabledButtonRawValues.contains(button.rawValue) { continue }

            if type == button.mouseDownType {
                // 中ボタン(OtherMouse)の場合は、ボタン番号が正しいかチェック
                if type == .otherMouseDown {
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber != 2 { continue } // 2が中ボタン
                }

                // すでにロックされている場合は、アプリのフィルタに関係なく解除を優先する
                if buttonStates[button] == .locked {
                    #if DEBUG
                    print("\(button) down while locked: Releasing lock")
                    #endif
                    releaseLock(for: button)
                    return Unmanaged.passUnretained(event)
                }

                if !shouldLock(at: currentLocation) {
                    #if DEBUG
                    print("\(button) down at \(currentLocation): Current app is filtered out")
                    #endif
                    if buttonStates[button] == .holding {
                        cancelHold(for: button)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if buttonStates[button] == .idle {
                    #if DEBUG
                    print("\(button) down at \(currentLocation): Starting tracking")
                    #endif
                    updateButtonState(button, to: .holding)
                    dragStartLocations[button] = currentLocation
                    lastLocation = currentLocation
                    
                    if lockType == .time || lockType == .both {
                        DispatchQueue.main.async {
                            self.startTimer(for: button)
                        }
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            if type == button.mouseUpType {
                if type == .otherMouseUp {
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber != 2 { continue }
                }

                if buttonStates[button] == .holding {
                    #if DEBUG
                    print("\(button) up: Normal click, canceling timer")
                    #endif
                    cancelHold(for: button)
                    return Unmanaged.passUnretained(event)
                } else if buttonStates[button] == .locked {
                    #if DEBUG
                    print("\(button) up while locked: Ignoring to keep the lock")
                    #endif
                    return nil
                }
            }
        }

        // ドラッグ・移動イベントの処理
        if type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged || type == .mouseMoved {
            lastLocation = currentLocation
            
            if (lockType == .distance || lockType == .both) && !isLocked {
                for button in MouseButton.allCases {
                    if buttonStates[button] == .holding, let startLocation = dragStartLocations[button] {
                        let distance = sqrt(pow(currentLocation.x - startLocation.x, 2) + pow(currentLocation.y - startLocation.y, 2))
                        
                        if distance >= lockDistance {
                            // ロックするかどうかの判定はマウスダウン時に行われているため、ここでは判定せずにロックを開始する
                            #if DEBUG
                            print("\(button) distance (\(distance)) exceeded threshold (\(lockDistance)) at \(currentLocation): Locking")
                            #endif
                            updateButtonState(button, to: .locked)
                            break
                        }
                    }
                }
            }

            // いずれかのボタンがロック中なら、カスタムカーソルの位置を更新
            if isLocked {
                CursorManager.shared.updatePosition()

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
                return Unmanaged.passUnretained(event)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func updateButtonState(_ button: MouseButton, to newState: EventManagerState) {
        let oldState = buttonStates[button]
        buttonStates[button] = newState

        // ロック中のボタンセットを更新
        if newState == .locked {
            if !lockedButtons.contains(button) {
                lockedButtons.insert(button)
            }
        } else {
            if lockedButtons.contains(button) {
                lockedButtons.remove(button)
            }
        }

        // グローバルのロック状態を更新
        let anyLocked = !lockedButtons.isEmpty
        if self.isLocked != anyLocked {
            DispatchQueue.main.async {
                self.isLocked = anyLocked
            }
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
                    // ロックするかどうかの判定はマウスダウン時に行われているため、ここでは判定せずにロックを開始する
                    #if DEBUG
                    print("Timer fired: \(button) Lock active!")
                    #endif
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

    func pauseForOnboarding() {
        isProcessingNotificationAction = true
        isEnabled = false
        isProcessingNotificationAction = false
    }

    func resumeFromOnboarding() {
        isProcessingNotificationAction = true
        isEnabled = true
        isProcessingNotificationAction = false
    }

    func toggleEnabled(isSilent: Bool = false) {
        // オンボーディングが完了していない場合は状態の切り替え（再開）を許可しない
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        
        if isSilent {
            self.isProcessingNotificationAction = true
        }
        isEnabled.toggle()
        if isSilent {
            self.isProcessingNotificationAction = false
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
        #if DEBUG
        print("Synthetic \(button) mouse up posted")
        #endif
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

    private var isUpdatingSettings = false

    private func saveCurrentIconSettings() {
        // ロード中や初期化中は保存しない（意図しない上書き防止）
        guard !isUpdatingSettings && !isInitializing else { return }
        
        let style = pointerIconStyle.rawValue
        
        // すべてのアイコンの設定を保存する（再起動時の永続化のため）
        iconSettings["\(style)_scale"] = customIconScale
        iconSettings["\(style)_opacity"] = customIconOpacity
        iconSettings["\(style)_xOffset"] = customIconXOffset
        iconSettings["\(style)_yOffset"] = customIconYOffset
        
        UserDefaults.standard.set(iconSettings, forKey: "allIconSettings")
    }
    
    private func loadIconSettings(for style: IconStyle, resetToDefaults: Bool) {
        isUpdatingSettings = true
        defer { isUpdatingSettings = false }
        
        let styleStr = style.rawValue
        
        if resetToDefaults {
            // デフォルト値を適用
            if customIconScale != style.defaultScale { customIconScale = style.defaultScale }
            if customIconOpacity != style.defaultOpacity { customIconOpacity = style.defaultOpacity }
            if customIconXOffset != style.defaultXOffset { customIconXOffset = style.defaultXOffset }
            if customIconYOffset != style.defaultYOffset { customIconYOffset = style.defaultYOffset }
        } else {
            // 保存された値をロード、なければデフォルト
            let newScale = iconSettings["\(styleStr)_scale"] ?? style.defaultScale
            if customIconScale != newScale { customIconScale = newScale }
            
            let newOpacity = iconSettings["\(styleStr)_opacity"] ?? style.defaultOpacity
            if customIconOpacity != newOpacity { customIconOpacity = newOpacity }
            
            let newX = iconSettings["\(styleStr)_xOffset"] ?? style.defaultXOffset
            if customIconXOffset != newX { customIconXOffset = newX }
            
            let newY = iconSettings["\(styleStr)_yOffset"] ?? style.defaultYOffset
            if customIconYOffset != newY { customIconYOffset = newY }
        }
        
        isUpdatingSettings = false
        saveCurrentIconSettings()
    }

    func resetIconSettings() {
        isUpdatingSettings = true
        defer { 
            isUpdatingSettings = false 
            saveCurrentIconSettings()
        }
        
        customIconScale = pointerIconStyle.defaultScale
        customIconOpacity = pointerIconStyle.defaultOpacity
        customIconXOffset = pointerIconStyle.defaultXOffset
        customIconYOffset = pointerIconStyle.defaultYOffset
    }
}

extension EventManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == resumeActionIdentifier {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isProcessingNotificationAction = true
                if !self.isEnabled {
                    self.isEnabled = true
                }
                self.isProcessingNotificationAction = false
            }
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでも通知を表示する
        completionHandler([.banner, .list, .sound])
    }
}

// C関数としてのコールバック
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventManager>.fromOpaque(refcon).takeUnretainedValue()
    
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}
