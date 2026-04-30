import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers
import Combine

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.layoutDirection) private var systemLayoutDirection
    @AppStorage("lockDelay") private var lockDelay: Double = 1.0
    @State private var hoverTask: Task<Void, Never>? = nil
    @State private var isShowingManagedAppPopover = false
    @State private var showAllRunningApps = false
    @State private var selectedManagedAppIds: Set<String> = []
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var showingInvalidAppAlert = false
    @State private var showingClearAllManagedAppsConfirmation = false
    @State private var showingAudioLengthError = false
    @State private var audioErrorMessage = ""
    @State private var showingDeleteSoundConfirmation = false
    @State private var soundIndexToDelete: Int = 1
    @State private var soundNameToDelete: String = ""
    @State private var previewCursorPhase: Int = 0
    @State private var showingCustomIconError = false
    @State private var iconErrorMessage = ""
    @State private var showingDeleteIconConfirmation = false
    @State private var iconNameToDelete = ""
    @State private var showingResetIconSettingsConfirmation = false
    @State private var isAppActive = true
    @State private var cachedTrimmedImage: (path: String, image: NSImage, originalSize: NSSize)? = nil
    @State private var cachedOriginalImage: NSImage? = nil
    @State private var cachedOriginalImagePath: String? = nil
    @State private var customIconPreviewImage: Image? = nil
    @State private var iconPreloadTask: Task<Void, Never>? = nil
    
    // タブの選択状態を管理するための列挙型と状態変数
    enum Tab: Hashable {
        case general, customization, behavior, info
    }
    @State private var selectedTab: Tab
    private let shouldResetOnAppear: Bool
    
    init(initialTab: Tab = .general, shouldResetOnAppear: Bool = true) {
        self._selectedTab = State(initialValue: initialTab)
        self.shouldResetOnAppear = shouldResetOnAppear
    }
    
    private static var iconCache: [IconStyle: Image] = [:]

    private func getIcon(for style: IconStyle) -> Image {
        // カスタムスタイルの場合はバックグラウンドで生成済みのキャッシュを使用
        if style == .custom {
            if let cached = customIconPreviewImage {
                return cached
            }
            // まだロードされていない場合は空の画像を返す（バックグラウンドでロード中）
            return Image(nsImage: NSImage(size: CGSize(width: 16, height: 16)))
        }
        
        if let cached = Self.iconCache[style] {
            return cached
        }
        let generated = generateIcon(for: style)
        Self.iconCache[style] = generated
        return generated
    }

    private func generateIcon(for style: IconStyle) -> Image {
        let view: AnyView
        switch style {
        case .padlock:
            view = AnyView(Image("Pointer_Locked").frame(width: 16, height: 16, alignment: .center))
        case .dot:
            view = AnyView(ZStack(alignment: .center) {
                Circle().fill(Color.white).frame(width: 8, height: 8)
                Circle().fill(Color.black).frame(width: 6, height: 6)
            }.frame(width: 16, height: 16, alignment: .center))
        case .largeRing:
            view = AnyView(Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 13, height: 13)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 13, height: 13)
                )
                .frame(width: 16, height: 16, alignment: .center))
        case .trafficLight:
            let scale = 16.0 / 35.0
            view = AnyView(HStack(spacing: 3 * scale) {
                Circle().fill(Color.green).frame(width: 7 * scale, height: 7 * scale)
                Circle().fill(Color.yellow).frame(width: 7 * scale, height: 7 * scale)
                Circle().fill(Color.red).frame(width: 7 * scale, height: 7 * scale)
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
            .frame(width: 16, height: 16, alignment: .center))
        case .smallTrafficLight:
            let scale = 16.0 / 24.0
            view = AnyView(HStack(spacing: 2 * scale) {
                Circle().fill(Color.green).frame(width: 5 * scale, height: 5 * scale)
                Circle().fill(Color.yellow).frame(width: 5 * scale, height: 5 * scale)
                Circle().fill(Color.red).frame(width: 5 * scale, height: 5 * scale)
            }
            .padding(.horizontal, 2.5 * scale)
            .padding(.vertical, 2 * scale)
            .background(
                Capsule()
                    .fill(Color.black)
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1.0 * scale)
                    )
            )
            .frame(width: 16, height: 16, alignment: .center))
        case .trafficLightVertical:
            let scale = 16.0 / 35.0
            view = AnyView(VStack(spacing: 3 * scale) {
                Circle().fill(Color.green).frame(width: 7 * scale, height: 7 * scale)
                Circle().fill(Color.yellow).frame(width: 7 * scale, height: 7 * scale)
                Circle().fill(Color.red).frame(width: 7 * scale, height: 7 * scale)
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
            .frame(width: 16, height: 16, alignment: .center))
        case .smallTrafficLightVertical:
            let scale = 16.0 / 24.0
            view = AnyView(VStack(spacing: 2 * scale) {
                Circle().fill(Color.green).frame(width: 5 * scale, height: 5 * scale)
                Circle().fill(Color.yellow).frame(width: 5 * scale, height: 5 * scale)
                Circle().fill(Color.red).frame(width: 5 * scale, height: 5 * scale)
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
            .frame(width: 16, height: 16, alignment: .center))
        case .textHorizontal:
            view = AnyView(HStack(spacing: 1) {
                Text(verbatim: "L")
                Text(verbatim: "M").padding(.leading, -1.5)
                Text(verbatim: "R")
            }
            .font(.system(size: 6.5, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 2)
            .frame(height: 9)
            .background(
                Capsule()
                    .fill(Color.black)
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1.0)
                    )
            )
            .frame(width: 16, height: 16, alignment: .center))
        case .textVertical:
            view = AnyView(VStack(spacing: -1.2) {
                Text(verbatim: "L")
                Text(verbatim: "M")
                Text(verbatim: "R")
            }
            .font(.system(size: 4, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.vertical, 0.5)
            .frame(width: 7)
            .background(
                Capsule()
                    .fill(Color.black)
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1.0)
                    )
            )
            .frame(width: 16, height: 16, alignment: .center))
        case .focus:
            view = AnyView(ZStack {
                FocusCorner(length: 5, thickness: 2, innerThickness: 1, alignment: .topLeading, containerSize: 16)
                FocusCorner(length: 5, thickness: 2, innerThickness: 1, alignment: .topTrailing, containerSize: 16)
                FocusCorner(length: 5, thickness: 2, innerThickness: 1, alignment: .bottomLeading, containerSize: 16)
                FocusCorner(length: 5, thickness: 2, innerThickness: 1, alignment: .bottomTrailing, containerSize: 16)
            }.frame(width: 16, height: 16, alignment: .center))
        case .custom:
            if let path = eventManager.customIconPath {
                let trimmedImage: NSImage
                let originalSize: NSSize
                
                if let cached = cachedTrimmedImage, cached.path == path {
                    trimmedImage = cached.image
                    originalSize = cached.originalSize
                } else {
                    // キャッシュがない場合は空の画像を返す（バックグラウンドでロード中）
                    trimmedImage = NSImage()
                    originalSize = NSSize(width: 1, height: 1)
                }
                
                // プレビューエリア（80x80）でのベースとなるフィット倍率（実寸ベース）
                let fitScale = min(1.0, 80.0 / max(1, originalSize.width), 80.0 / max(1, originalSize.height))
                
                // プレビュー上でのコンテンツ（トリミング後の領域）の表示サイズ
                let contentDisplaySizeIn80 = max(trimmedImage.size.width, trimmedImage.size.height) * fitScale * eventManager.customIconScale
                
                // プレビュー上のサイズが 80px を超えた時だけ、ピッカー内でもズームを開始する
                // これにより、プレビューで見切れていないのにピッカーで見切れる現象を防ぐ
                let normalizedScale = contentDisplaySizeIn80 / 80.0
                
                view = AnyView(
                    Image(nsImage: trimmedImage)
                        .resizable()
                        .scaledToFit() // 全体が収まるようにフィットさせる
                        .frame(width: 16, height: 16)
                        .scaleEffect(max(1.0, normalizedScale)) // 1.0未満にはしない（＝余計な余白を作らない）
                        .opacity(eventManager.customIconOpacity) // 不透明度を反映
                        .clipped()
                )
            } else {
                view = AnyView(Color.clear.frame(width: 16, height: 16))
            }
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }
    
    @ViewBuilder
    private func previewIcon(for style: IconStyle) -> some View {
        getIcon(for: style)
            .resizable()
            .frame(width: 16, height: 16)
    }
    
    private func methodButton(imageName: String, title: LocalizedStringResource, type: LockType) -> some View {
        let isSelected = eventManager.lockType == type
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                eventManager.lockType = type
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80) // ユーザー指定の高さ 80
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.system(size: 14))
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 5, y: 5)
                    }
                }
                .padding(.horizontal, -2.5)
                .padding(.bottom, -2.5)
                
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .frame(width: 60, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .help(Text("「\(String(localized: title))」方式でドラッグロックを開始します。"))
    }

    private func mouseButtonSelection(imageName: String, title: LocalizedStringResource, button: MouseButton) -> some View {
        let isSelected = eventManager.enabledButtonRawValues.contains(button.rawValue)
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    eventManager.enabledButtonRawValues.remove(button.rawValue)
                } else {
                    eventManager.enabledButtonRawValues.insert(button.rawValue)
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80) // ユーザー指定の高さ 80
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.system(size: 14))
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 5, y: 5)
                    }
                }
                .padding(.horizontal, -2.5)
                .padding(.bottom, -2.5)
                
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .frame(width: 60, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .help(Text("\(String(localized: title))ボタンをドラッグロックの対象にします。"))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 一般タブ
            Form {
                Section(header: Text("一般")) {
                    Toggle(isOn: Binding(
                        get: { eventManager.isLaunchAtLoginEnabled },
                        set: { eventManager.isLaunchAtLoginEnabled = $0 }
                    )) {
                        Text("ログイン時に開く")
                        Text("Macのログイン時にDragLockerを自動で起動します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ロック対象ボタン")
                            Text("ドラッグロックを使用するマウスボタンを選択します。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        mouseButtonSelection(imageName: "DragLocker_Button_Left", title: "左", button: .left)
                        mouseButtonSelection(imageName: "DragLocker_Button_Wheel", title: "ホイール", button: .middle)
                        mouseButtonSelection(imageName: "DragLocker_Button_Right", title: "右", button: .right)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ロック方法")
                            Text("ドラッグロックを開始する方法を選択します。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        methodButton(imageName: "DragLocker_Method_Time", title: "時間", type: .time)
                        methodButton(imageName: "DragLocker_Method_Distance", title: "距離", type: .distance)
                        methodButton(imageName: "DragLocker_Method_Both", title: "両方", type: .both)
                    }
                    
                    if eventManager.lockType == .time || eventManager.lockType == .both {
                        VStack(alignment: .leading) {
                            HStack(alignment: .center, spacing: 8) {
                                Slider(value: $lockDelay, in: 0.2...3.0, step: 0.1) {
                                    Text("ロックまでの時間")
                                }
                                Text("\(lockDelay, format: .number.precision(.fractionLength(1))) 秒")
                                    .foregroundStyle(.secondary)
                            }
                            Text("ドラッグロック開始までクリックし続ける時間を設定します。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $eventManager.isUnlockAllWithEscEnabled) {
                        Text("Escキーですべてのロックを解除")
                        Text("ドラッグロック中にEscキーを押してすべてのボタンのロックを解除します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if eventManager.lockType == .distance || eventManager.lockType == .both {
                        VStack(alignment: .leading) {
                            HStack(alignment: .center, spacing: 8) {
                                Slider(value: $eventManager.lockDistance, in: 10...500, step: 10) {
                                    Text("ロックまでの距離")
                                }
                                Text("\(eventManager.lockDistance, format: .number.precision(.fractionLength(0))) px")
                                    .foregroundStyle(.secondary)
                            }
                            Text("ドラッグロック開始までドラッグし続ける距離を設定します。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section(header: Text("状態")) {
                    HStack(alignment: .top) {
                        Group {
                            if !eventManager.isTrusted {
                                if differentiateWithoutColor {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(.red)
                                        .fontWeight(.bold)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                }
                            } else if eventManager.isEnabled {
                                if differentiateWithoutColor {
                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(.green)
                                        .fontWeight(.bold)
                                } else {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                }
                            } else {
                                if differentiateWithoutColor {
                                    Image(systemName: "pause.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(.orange)
                                        .fontWeight(.bold)
                                } else {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                        .offset(y: 3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ドラッグロック監視")
                            Group {
                                if !eventManager.isTrusted {
                                    Text("アクセシビリティ権限が必要")
                                } else if eventManager.isEnabled {
                                    Text("動作中")
                                } else {
                                    Text("一時停止中")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            eventManager.toggleEnabled()
                        }) {
                            HStack {
                                Image(systemName: eventManager.isEnabled ? "pause.fill" : "play.fill")
                                Text(eventManager.isEnabled ? "一時停止" : "再開")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!eventManager.isTrusted)
                        .help(eventManager.isEnabled ? "ドラッグロックの監視を一時停止します。" : "ドラッグロックの監視を再開します。")
                    }
                    
                    LabeledContent {
                        HStack(spacing: 8) {
                            KeyboardShortcuts.Recorder(for: .toggleMonitoring)
                            Button(action: {
                                KeyboardShortcuts.setShortcut(.init(.l, modifiers: [.command, .control, .shift]), for: .toggleMonitoring)
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("ショートカットをデフォルト（⌃ Control + ⇧ Shift + ⌘ Command + L）にリセットします。")
                        }
                    } label: {
                        Text("切り替えショートカット")
                    }
                    
                    Toggle(isOn: $eventManager.isNotificationEnabled) {
                        Text("切り替え時に通知を送信")
                        Text("ドラッグロックの切り替え時にシステム通知を表示します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text("権限")) {
                    HStack(alignment: .top) {
                        Group {
                            if differentiateWithoutColor {
                                Image(systemName: eventManager.isTrusted ? "checkmark" : "xmark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(eventManager.isTrusted ? .green : .red)
                                    .fontWeight(.bold)
                            } else {
                                Circle()
                                    .fill(eventManager.isTrusted ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .offset(y: 3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("アクセシビリティ")
                            Text("ドラッグロック機能を使用する場合は許可を与える必要があります。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            eventManager.requestAccessibilityPermissions()
                        }) {
                            HStack {
                                Image(systemName: eventManager.isTrusted ? "checkmark" : "gearshape.fill")
                                Text(eventManager.isTrusted ? "許可済み" : "設定を開く")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(eventManager.isTrusted)
                        .help(eventManager.isTrusted ? "アクセシビリティ許可が付与されています。" : "システム設定のアクセシビリティ許可設定を開きます。")
                    }
                    
                    HStack(alignment: .top) {
                        Group {
                            if differentiateWithoutColor {
                                Image(systemName: eventManager.isNotificationTrusted ? "checkmark" : "xmark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(eventManager.isNotificationTrusted ? .green : .red)
                                    .fontWeight(.bold)
                            } else {
                                Circle()
                                    .fill(eventManager.isNotificationTrusted ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .offset(y: 3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("通知")
                            Text("通知機能を使用するには許可を与える必要があります。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            if eventManager.isNotificationTrusted {
                                eventManager.sendTestNotification()
                            } else {
                                eventManager.openNotificationSettings()
                            }
                        }) {
                            HStack {
                                Image(systemName: eventManager.isNotificationTrusted ? "bell.badge.fill" : "gearshape.fill")
                                Text(eventManager.isNotificationTrusted ? "通知をテスト" : "設定を開く")
                            }
                        }
                        .buttonStyle(.bordered)
                        .help(eventManager.isNotificationTrusted ? "現在の通知設定を確認するためのテスト通知を送信します。" : "システム設定の通知設定画面を開きます。")
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("一般", systemImage: "gear")
            }
            .tag(Tab.general)
            
            // カスタマイズタブ
            Form {
                Section(header: Text("アイコン")) {
                    Toggle(isOn: Binding(
                        get: { eventManager.isIconEnabled },
                        set: { eventManager.isIconEnabled = $0 }
                    )) {
                        Text("アイコンをポインタ付近に表示")
                        Text("ドラッグロックされている間、マウスポインタ付近にアイコンを表示します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Picker(selection: $eventManager.pointerIconStyle.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                        Section("シングルインジケーター") {
                            Label { Text("南京錠") } icon: { previewIcon(for: .padlock) }.tag(IconStyle.padlock)
                            Label { Text("ドット") } icon: { previewIcon(for: .dot) }.tag(IconStyle.dot)
                            Label { Text("大きなリング") } icon: { previewIcon(for: .largeRing) }.tag(IconStyle.largeRing)
                            Label { Text("フォーカス") } icon: { previewIcon(for: .focus) }.tag(IconStyle.focus)
                            Label { Text("カスタム") } icon: { previewIcon(for: .custom) }.tag(IconStyle.custom)
                        }
                        
                        Section("マルチインジケーター") {
                            Label { Text("信号機（横）") } icon: { previewIcon(for: .trafficLight) }.tag(IconStyle.trafficLight)
                            Label { Text("信号機（縦）") } icon: { previewIcon(for: .trafficLightVertical) }.tag(IconStyle.trafficLightVertical)
                            Label { Text("小さな信号機（横）") } icon: { previewIcon(for: .smallTrafficLight) }.tag(IconStyle.smallTrafficLight)
                            Label { Text("小さな信号機（縦）") } icon: { previewIcon(for: .smallTrafficLightVertical) }.tag(IconStyle.smallTrafficLightVertical)
                            Label { Text("テキスト（横）") } icon: { previewIcon(for: .textHorizontal) }.tag(IconStyle.textHorizontal)
                            Label { Text("テキスト（縦）") } icon: { previewIcon(for: .textVertical) }.tag(IconStyle.textVertical)
                        }
                    } label: {
                        Text("アイコンスタイル")
                            .foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary)
                        Text("ドラッグロック中にマウスポインタ付近に表示されるアイコンのスタイルを選択します。")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                    }
                    .labelStyle(.titleAndIcon)
                    .pickerStyle(.menu)
                    .disabled(!eventManager.isIconEnabled)
                    
                    customIconSettingsView
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    Picker(selection: $eventManager.iconAnimation) {
                        Text(IconAnimation.default.localizedName).tag(IconAnimation.default)
                        Divider()
                        ForEach([IconAnimation.none, .fade, .scale, .pop, .popPlus, .focus, .focusPlus], id: \.self) { animation in
                            Text(animation.localizedName).tag(animation)
                        }
                    } label: {
                        Text("アニメーション")
                            .foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary)
                        Text("アイコン表示時と非表示時に適用されるアニメーションを選択します。")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                    }
                    .pickerStyle(.menu)
                    .disabled(!eventManager.isIconEnabled)
                }
                
                Section(header: Text("サウンド")) {
                    Toggle(isOn: Binding(
                        get: { eventManager.isSoundEnabled },
                        set: { eventManager.isSoundEnabled = $0 }
                    )) {
                        Text("サウンドを再生")
                        Text("ドラッグロックされた時と解除されたときにサウンドを再生します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(alignment: .top) {
                        Picker(selection: $eventManager.soundStyle.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                            ForEach(SoundStyle.allCases.filter { $0 != .custom }, id: \.self) { style in
                                Text(style.localizedName)
                                    .tag(style)
                                    .onHover { isHovering in
                                        if isHovering {
                                            SoundManager.shared.loadSound(style: style)
                                            hoverTask?.cancel()
                                            hoverTask = Task {
                                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                                if !Task.isCancelled {
                                                    SoundManager.shared.preview(style: style, volume: eventManager.soundVolume, isInverted: eventManager.isSoundInverted)
                                                }
                                            }
                                        } else {
                                            hoverTask?.cancel()
                                        }
                                    }
                                
                                if style == .system {
                                    Divider()
                                }
                            }
                            
                            Divider()
                            
                            Text(SoundStyle.custom.localizedName)
                                .tag(SoundStyle.custom)
                                .onHover { isHovering in
                                    if isHovering {
                                        SoundManager.shared.loadSound(style: .custom)
                                        hoverTask?.cancel()
                                        hoverTask = Task {
                                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                            if !Task.isCancelled {
                                                SoundManager.shared.preview(style: .custom, volume: eventManager.soundVolume, isInverted: eventManager.isSoundInverted)
                                            }
                                        }
                                    } else {
                                        hoverTask?.cancel()
                                    }
                                }
                        } label: {
                            Text("サウンドスタイル")
                                .foregroundStyle(eventManager.isSoundEnabled ? .primary : .secondary)
                            Text("再生するサウンドを選択します。マウスホバーでサウンドをプレビューできます。")
                                .font(.subheadline)
                                .foregroundStyle(eventManager.isSoundEnabled ? .secondary : .tertiary)
                        }
                        .pickerStyle(.menu)
                        .disabled(!eventManager.isSoundEnabled)
                        
                        Button {
                            SoundManager.shared.loadSound(style: eventManager.soundStyle)
                            SoundManager.shared.preview(style: eventManager.soundStyle, volume: eventManager.soundVolume, isInverted: eventManager.isSoundInverted)
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(eventManager.isSoundEnabled ? .secondary : .tertiary)
                        .disabled(!eventManager.isSoundEnabled)
                        .help("現在のサウンドをプレビュー再生します。")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            customSoundView(title: String(localized: "サウンド 1"), index: 1)
                            Divider()
                            customSoundView(title: String(localized: "サウンド 2"), index: 2)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        
                        Text("各サウンドには、最大10秒までのオーディオファイルを設定することができ、片方だけが設定された場合はロック時と解除時に同じサウンドが使用されます。")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.isSoundEnabled ? .secondary : .tertiary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 8) {
                            Slider(value: $eventManager.soundVolume, in: 0.0...1.0, step: 0.05) {
                                Text("サウンドの音量")
                                    .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .primary : .secondary)
                            }
                            .disabled(!eventManager.isSoundEnabled || eventManager.soundStyle == .system)
                            Text(eventManager.soundVolume, format: .percent.precision(.fractionLength(0)))
                                .foregroundStyle((!eventManager.isSoundEnabled || eventManager.soundStyle == .system) ? .tertiary : .secondary)
                        }
                        Text("カスタムサウンドの再生音量を調整します。")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .secondary : .tertiary)
                    }
                    
                    Toggle(isOn: $eventManager.isSoundInverted) {
                        Text("サウンドを反転")
                            .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .primary : .secondary)
                        Text("ドラッグロックされた時と解除された時に再生されるサウンドを入れ替えます。")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .secondary : .tertiary)
                    }
                    .disabled(!eventManager.isSoundEnabled || eventManager.soundStyle == .system)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                if #available(macOS 26.0, *) {
                    Label("カスタマイズ", systemImage: "pointer.arrow.rays")
                } else {
                    Label("カスタマイズ", systemImage: "cursorarrow.rays")
                }
            }
            .tag(Tab.customization)
            
            // 動作タブ
            Form {
                ManagedAppSettingsSection(
                    eventManager: eventManager,
                    isShowingManagedAppPopover: $isShowingManagedAppPopover,
                    showAllRunningApps: $showAllRunningApps,
                    selectedManagedAppIds: $selectedManagedAppIds,
                    runningApplications: $runningApplications,
                    showingInvalidAppAlert: $showingInvalidAppAlert,
                    showingClearAllManagedAppsConfirmation: $showingClearAllManagedAppsConfirmation
                )
            }
            .formStyle(.grouped)
            .tabItem {
                if #available(macOS 26.0, *) {
                    Label("動作", systemImage: "pointer.arrow.and.square.on.square.dashed")
                } else {
                    Label("動作", systemImage: "cursorarrow.and.square.on.square.dashed")
                }
            }
            .tag(Tab.behavior)
            
            // 情報タブ
            InfoView()
                .tabItem {
                    Label("情報", systemImage: "info.circle")
                }
                .tag(Tab.info)
        }
        .navigationTitle("DragLocker 設定")
        .onAppear {
            runningApplications = NSWorkspace.shared.runningApplications
            // 設定画面表示時はDockアイコンを表示する
            NSApp.setActivationPolicy(.regular)
            // アプリを前面に持ってくる
            NSApp.activate(ignoringOtherApps: true)
            // 設定画面を開くたびに「一般」タブにリセットする（プレビュー以外）
            if shouldResetOnAppear {
                selectedTab = .general
            }
            // カスタムアイコンのバックグラウンドプリロード
            preloadCustomIconImages()
        }
        .onChange(of: lockDelay) { _, newValue in
            eventManager.lockDelay = newValue
        }
        .onDisappear {
            // 設定画面を閉じるときにメモリを整理
            SoundManager.shared.cleanupExcept(activeStyle: eventManager.soundStyle)
            // 大量にメモリを消費する可能性のあるリストをクリア
            runningApplications = []
            selectedManagedAppIds = []
            hoverTask?.cancel()
            hoverTask = nil
            iconPreloadTask?.cancel()
            iconPreloadTask = nil
            // カスタムアイコンのキャッシュをクリア
            cachedOriginalImage = nil
            cachedOriginalImagePath = nil
            cachedTrimmedImage = nil
            customIconPreviewImage = nil
            // 設定画面を閉じたらDockアイコンを非表示にする
            NSApp.setActivationPolicy(.accessory)
        }
        .onChange(of: eventManager.customIconPath) { _, _ in
            preloadCustomIconImages()
        }
        .onChange(of: eventManager.customIconScale) { _, _ in
            refreshCustomIconPreview()
        }
        .onChange(of: eventManager.customIconOpacity) { _, _ in
            refreshCustomIconPreview()
        }
        .alert("音声が長すぎます", isPresented: $showingAudioLengthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("最大10秒までのオーディオファイルを設定することができます。")
        }
        .alert("サウンド\(soundIndexToDelete)を削除", isPresented: $showingDeleteSoundConfirmation) {
            Button("削除", role: .destructive) {
                eventManager.deleteCustomSound(index: soundIndexToDelete)
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("サウンド\(soundIndexToDelete)に設定されたカスタムサウンド「\(soundNameToDelete)」を削除してもよろしいですか？")
        }
    }
    
    private func customSoundView(title: String, index: Int) -> some View {
        let isCustom = eventManager.soundStyle == .custom
        let isEnabled = eventManager.isSoundEnabled
        
        let fileName = index == 1 ? eventManager.customSound1Name : eventManager.customSound2Name
        
        // 表示名の決定
        let displayName: String
        if isCustom {
            displayName = fileName.map { ($0 as NSString).deletingPathExtension } ?? String(localized: "ファイルが選択されていません")
        } else if eventManager.soundStyle == .system {
            displayName = String(localized: "システム")
        } else {
            let styleName = String(localized: eventManager.soundStyle.localizedName)
            let suffix = index == 1 ? String(localized: " 上") : String(localized: " 下")
            displayName = styleName + suffix
        }
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                
                Spacer()
                
                Button {
                    if isCustom {
                        SoundManager.shared.playByKey(key: "custom_\(index)", volume: eventManager.soundVolume)
                    } else {
                        // 標準スタイルの個別プレビュー（上・下を独立して試聴）
                        SoundManager.shared.play(
                            style: eventManager.soundStyle,
                            volume: eventManager.soundVolume,
                            isLocked: index == 1,
                            isInverted: false // 個別プレビューでは反転設定を無視して本来の音を確認できるようにする
                        )
                    }
                } label: {
                    Image(systemName: "play.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isEnabled ? .secondary : .tertiary)
                .disabled(!isEnabled || (isCustom && fileName == nil) || eventManager.soundStyle == .system)
                .help(Text("\(title)をプレビュー再生します。"))
            }
            
            Text(displayName)
                .font(.subheadline)
                .foregroundStyle(isEnabled ? .secondary : .tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.bottom, 16)
                .help(displayName)
            
            HStack {
                Button("選択...") {
                    selectAudioFile(index: index)
                }
                .disabled(!isEnabled || !isCustom)
                .help("Finderからオーディオファイルを選択します。")
                
                Button("削除...", role: .destructive) {
                    soundIndexToDelete = index
                    soundNameToDelete = displayName
                    showingDeleteSoundConfirmation = true
                }
                .disabled(!isEnabled || !isCustom || fileName == nil)
                .help("設定されたカスタムオーディオを削除します。")
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func selectAudioFile(index: Int) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mp3, .quickTimeMovie] // mp4などオーディオが含まれるものも考慮
        
        guard let window = NSApp.keyWindow else {
            // ウィンドウが見つからない場合はフォールバック
            if panel.runModal() == .OK, let url = panel.url {
                Task {
                    try? await eventManager.saveCustomSound(url: url, index: index)
                }
            }
            return
        }
        
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        try await self.eventManager.saveCustomSound(url: url, index: index)
                    } catch {
                        self.audioErrorMessage = error.localizedDescription
                        self.showingAudioLengthError = true
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var customIconSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                // 左側：プレビュー画像エリア
                ZStack {
                    let isOld = ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26
                    let suffix = isOld ? "_Old" : ""
                    let cursors = ["Cursor_Pointer\(suffix)", "Cursor_PointingHand\(suffix)", "Cursor_IbeamVertical\(suffix)"]
                    let currentCursorName = cursors[previewCursorPhase % cursors.count]
                    
                    Group {
                        if eventManager.pointerIconStyle == .custom {
                            if let nsImage = cachedOriginalImage {
                                let fitScale = min(1.0, 80.0 / max(1, nsImage.size.width), 80.0 / max(1, nsImage.size.height))
                                let displayWidth = nsImage.size.width * fitScale * eventManager.customIconScale
                                let displayHeight = nsImage.size.height * fitScale * eventManager.customIconScale
                                
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: displayWidth, height: displayHeight)
                            } else {
                                Color.clear
                            }
                        } else {
                            iconPreviewArea
                        }
                    }
                    .frame(width: 80, height: 80, alignment: .center)
                    .opacity(eventManager.customIconOpacity)
                    .clipped()
                    .offset(
                        x: eventManager.customIconXOffset,
                        y: eventManager.customIconYOffset
                    )
                    
                    ForEach(cursors, id: \.self) { cursor in
                        Image(cursor)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .opacity(cursor == currentCursorName ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.5), value: currentCursorName)
                    }
                }
                .frame(width: 160, height: 160)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
                    if isAppActive {
                        previewCursorPhase += 1
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    isAppActive = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    isAppActive = false
                }

                // 右側：画像選択・削除ボタンと説明テキスト
                VStack(alignment: .leading, spacing: 0) {
                    Text(eventManager.pointerIconStyle == .custom ? "カスタム画像" : "アイコンプレビュー")
                        .foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary)
                    
                    let displayName = eventManager.pointerIconStyle == .custom ? (eventManager.customIconName ?? String(localized: "ファイルが選択されていません")) : String(localized: eventManager.pointerIconStyle.localizedName)
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(displayName)
                    
                    HStack {
                        Button("選択...") {
                            selectCustomIcon()
                        }
                        .disabled(eventManager.pointerIconStyle != .custom)
                        
                        Button("削除...", role: .destructive) {
                            iconNameToDelete = eventManager.customIconName ?? ""
                            showingDeleteIconConfirmation = true
                        }
                        .disabled(eventManager.pointerIconStyle != .custom || eventManager.customIconPath == nil || !eventManager.isIconEnabled)
                    }
                    .padding(.vertical, 16)
                    .disabled(!eventManager.isIconEnabled)
                    .alert("カスタム画像を削除", isPresented: $showingDeleteIconConfirmation) {
                        Button("削除", role: .destructive) {
                            eventManager.deleteCustomIcon()
                        }
                        Button("キャンセル", role: .cancel) { }
                    } message: {
                        Text("設定されたカスタム画像「\(iconNameToDelete)」を削除してもよろしいですか？")
                    }
                    
                    Text("80 × 80（Retinaディスプレイでは160 × 160）ピクセル以下の透過画像を使用することを推奨します。\n大きな画像は表示エリア（80 × 80）に収まるように縮小されます。")
                        .font(.subheadline)
                        .foregroundStyle((eventManager.isIconEnabled && eventManager.pointerIconStyle == .custom) ? .secondary : .tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // 下部：スライダー
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Slider(
                        value: $eventManager.customIconScale,
                        in: 0.01...2.0,
                        step: 0.01,
                        label: { Text("大きさ").foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary) }
                    )
                    Text(eventManager.customIconScale, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
                
                HStack(spacing: 8) {
                    Slider(
                        value: $eventManager.customIconOpacity,
                        in: 0.1...1.0,
                        step: 0.01,
                        label: { Text("不透明度").foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary) }
                    )
                    Text(eventManager.customIconOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
                
                HStack(spacing: 8) {
                    Slider(
                        value: $eventManager.customIconXOffset,
                        in: -40...40,
                        step: 1,
                        label: { Text("Xオフセット").foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary) }
                    )
                    Text(Int(eventManager.customIconXOffset), format: .number)
                        .monospacedDigit()
                        .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
                
                HStack(spacing: 8) {
                    Slider(
                        value: $eventManager.customIconYOffset,
                        in: -40...40,
                        step: 1,
                        label: { Text("Yオフセット").foregroundStyle(eventManager.isIconEnabled ? .primary : .secondary) }
                    )
                    Text(Int(eventManager.customIconYOffset), format: .number)
                        .monospacedDigit()
                        .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .disabled(!eventManager.isIconEnabled)
                
                HStack {
                    Spacer()
                    Button("リセット...") {
                        showingResetIconSettingsConfirmation = true
                    }
                    .disabled(!eventManager.isIconEnabled)
                    .alert("設定をリセットしますか？", isPresented: $showingResetIconSettingsConfirmation) {
                        Button("リセット", role: .destructive) {
                            eventManager.resetIconSettings()
                        }
                        Button("キャンセル", role: .cancel) { }
                    } message: {
                        Text("大きさ、不透明度、Xオフセット、Yオフセットを既定値に戻してもよろしいですか？")
                    }
                }
            }
        }

    /// バックグラウンドでカスタムアイコン画像を読み込み、キャッシュを更新する
    private func preloadCustomIconImages() {
        iconPreloadTask?.cancel()
        
        guard let path = eventManager.customIconPath else {
            cachedOriginalImage = nil
            cachedOriginalImagePath = nil
            cachedTrimmedImage = nil
            customIconPreviewImage = nil
            return
        }
        
        // 既にキャッシュ済みの場合はプレビューだけ再生成
        if cachedOriginalImagePath == path, cachedOriginalImage != nil {
            refreshCustomIconPreview()
            return
        }
        
        let scale = eventManager.customIconScale
        let opacity = eventManager.customIconOpacity
        
        iconPreloadTask = Task.detached(priority: .userInitiated) {
            guard let nsImage = NSImage(contentsOfFile: path) else { return }
            let originalSize = nsImage.size
            let trimmed = nsImage.trimmedToOpaqueContent()
            
            // Pickerアイコンプレビュー（16x16）の生成
            let previewImage = await Self.generateCustomIconPreview(
                trimmedImage: trimmed,
                originalSize: originalSize,
                scale: scale,
                opacity: opacity
            )
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.cachedOriginalImage = nsImage
                self.cachedOriginalImagePath = path
                self.cachedTrimmedImage = (path, trimmed, originalSize)
                self.customIconPreviewImage = previewImage
            }
        }
    }
    
    /// スライダー変更時にPickerアイコンプレビューだけを再生成する
    private func refreshCustomIconPreview() {
        guard let cached = cachedTrimmedImage else { return }
        
        let trimmed = cached.image
        let originalSize = cached.originalSize
        let scale = eventManager.customIconScale
        let opacity = eventManager.customIconOpacity
        
        Task.detached(priority: .userInitiated) {
            let previewImage = await Self.generateCustomIconPreview(
                trimmedImage: trimmed,
                originalSize: originalSize,
                scale: scale,
                opacity: opacity
            )
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.customIconPreviewImage = previewImage
            }
        }
    }
    
    /// バックグラウンドスレッドで16x16のPickerプレビューアイコンを生成する
    @MainActor
    private static func generateCustomIconPreview(
        trimmedImage: NSImage,
        originalSize: NSSize,
        scale: Double,
        opacity: Double
    ) -> Image {
        let fitScale = min(1.0, 80.0 / max(1, originalSize.width), 80.0 / max(1, originalSize.height))
        let contentDisplaySizeIn80 = max(trimmedImage.size.width, trimmedImage.size.height) * fitScale * scale
        let normalizedScale = contentDisplaySizeIn80 / 80.0
        
        let view = AnyView(
            SwiftUI.Image(nsImage: trimmedImage)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .scaleEffect(max(1.0, normalizedScale))
                .opacity(opacity)
                .clipped()
        )
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }

    @ViewBuilder
    private var iconPreviewArea: some View {
        let style = eventManager.pointerIconStyle
        
        let scale = eventManager.customIconScale
        
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
                ZStack {
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .topLeading, containerSize: 40 * scale)
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .topTrailing, containerSize: 40 * scale)
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .bottomLeading, containerSize: 40 * scale)
                    FocusCorner(length: 12 * scale, thickness: 4 * scale, innerThickness: 2 * scale, alignment: .bottomTrailing, containerSize: 40 * scale)
                }
                .frame(width: 40 * scale, height: 40 * scale)
                .padding(4 * scale)
            } else if style == .trafficLight {
                HStack(spacing: 3 * scale) {
                    Circle().fill(Color.green).frame(width: 7 * scale, height: 7 * scale)
                    Circle().fill(Color.yellow).frame(width: 7 * scale, height: 7 * scale)
                    Circle().fill(Color.red).frame(width: 7 * scale, height: 7 * scale)
                }
                .padding(.horizontal, 4 * scale).padding(.vertical, 3 * scale)
                .background(Capsule().fill(Color.black).overlay(Capsule().stroke(Color.white, lineWidth: 1.0 * scale)))
            } else if style == .smallTrafficLight {
                HStack(spacing: 2 * scale) {
                    Circle().fill(Color.green).frame(width: 5 * scale, height: 5 * scale)
                    Circle().fill(Color.yellow).frame(width: 5 * scale, height: 5 * scale)
                    Circle().fill(Color.red).frame(width: 5 * scale, height: 5 * scale)
                }
                .padding(.horizontal, 2.5 * scale).padding(.vertical, 2 * scale)
                .background(Capsule().fill(Color.black).overlay(Capsule().stroke(Color.white, lineWidth: 1.0 * scale)))
            } else if style == .trafficLightVertical {
                VStack(spacing: 3 * scale) {
                    Circle().fill(Color.green).frame(width: 7 * scale, height: 7 * scale)
                    Circle().fill(Color.yellow).frame(width: 7 * scale, height: 7 * scale)
                    Circle().fill(Color.red).frame(width: 7 * scale, height: 7 * scale)
                }
                .padding(.horizontal, 3 * scale).padding(.vertical, 4 * scale)
                .background(Capsule().fill(Color.black).overlay(Capsule().stroke(Color.white, lineWidth: 1.0 * scale)))
            } else if style == .smallTrafficLightVertical {
                VStack(spacing: 2 * scale) {
                    Circle().fill(Color.green).frame(width: 5 * scale, height: 5 * scale)
                    Circle().fill(Color.yellow).frame(width: 5 * scale, height: 5 * scale)
                    Circle().fill(Color.red).frame(width: 5 * scale, height: 5 * scale)
                }
                .padding(.horizontal, 2 * scale).padding(.vertical, 2.5 * scale)
                .background(Capsule().fill(Color.black).overlay(Capsule().stroke(Color.white, lineWidth: 1.0 * scale)))
            } else if style == .textHorizontal {
                HStack(spacing: 1 * scale) {
                    Text(verbatim: "L").opacity(1.0)
                    Text(verbatim: "M").opacity(1.0).padding(.leading, -1.5 * scale)
                    Text(verbatim: "R").opacity(1.0)
                }
                .font(.system(size: 11 * scale, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 4 * scale).padding(.vertical, 2 * scale)
                .background(Capsule().fill(Color.black).overlay(Capsule().stroke(Color.white, lineWidth: 1.0 * scale)))
            } else if style == .textVertical {
                VStack(spacing: -2.8 * scale) {
                    Text(verbatim: "L").opacity(1.0)
                    Text(verbatim: "M").opacity(1.0)
                    Text(verbatim: "R").opacity(1.0)
                }
                .font(.system(size: 8 * scale, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 3 * scale).padding(.vertical, 3 * scale)
                .background(Capsule().fill(Color.black).overlay(Capsule().stroke(Color.white, lineWidth: 1.0 * scale)))
            }
        }
    }

    private func selectCustomIcon() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        
        guard let window = NSApp.keyWindow else {
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try eventManager.saveCustomIcon(url: url)
                } catch {
                    iconErrorMessage = error.localizedDescription
                    showingCustomIconError = true
                }
            }
            return
        }
        
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                do {
                    try eventManager.saveCustomIcon(url: url)
                } catch {
                    iconErrorMessage = error.localizedDescription
                    showingCustomIconError = true
                }
            }
        }
    }
}

extension NSImage {
    /// 画像の透明な余白を検出し、不透明な領域（アルファ値 > 0）だけにトリミングした新しい画像を返します。
    nonisolated func trimmedToOpaqueContent() -> NSImage {
        guard let tiffData = self.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else { return self }
        
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundOpaque = false
        
        for y in 0..<height {
            for x in 0..<width {
                let alpha = bitmapRep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if alpha > 0 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                    foundOpaque = true
                }
            }
        }
        
        if !foundOpaque { return self }
        
        // ピクセル単位の矩形
        let pixelRect = NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        
        // ポイント単位に変換（Retina対応）
        let scaleX = self.size.width / CGFloat(width)
        let scaleY = self.size.height / CGFloat(height)
        let pointRect = NSRect(x: CGFloat(minX) * scaleX,
                               y: CGFloat(minY) * scaleY,
                               width: CGFloat(pixelRect.width) * scaleX,
                               height: CGFloat(pixelRect.height) * scaleY)
        
        let trimmed = NSImage(size: pointRect.size)
        trimmed.lockFocus()
        // 画像は通常、上下逆さまに描画されることがあるため注意が必要
        self.draw(in: NSRect(origin: .zero, size: pointRect.size),
                  from: NSRect(x: pointRect.origin.x,
                               y: self.size.height - pointRect.maxY, // y座標の反転
                               width: pointRect.width,
                               height: pointRect.height),
                  operation: .copy,
                  fraction: 1.0)
        trimmed.unlockFocus()
        
        return trimmed
    }
}

#Preview("一般") {
    SettingsView(initialTab: .general, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}

#Preview("カスタマイズ") {
    SettingsView(initialTab: .customization, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}

#Preview("動作") {
    SettingsView(initialTab: .behavior, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}

#Preview("情報") {
    SettingsView(initialTab: .info, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}