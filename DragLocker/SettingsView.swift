import SwiftUI
import KeyboardShortcuts

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
    
    private var padlockPreviewImage: Image {
        let view = Image("Pointer_Locked")
            .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }

    private var dotImage: Image {
        let view = ZStack(alignment: .center) {
            Circle().fill(Color.white).frame(width: 8, height: 8)
            Circle().fill(Color.black).frame(width: 6, height: 6)
        }
        .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }
    
    private var largeRingImage: Image {
        let view = Circle()
            .stroke(Color.white, lineWidth: 4 * (16.0/48.0))
            .frame(width: 40 * (16.0/48.0), height: 40 * (16.0/48.0))
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 2 * (16.0/48.0))
                    .frame(width: 40 * (16.0/48.0), height: 40 * (16.0/48.0))
            )
            .padding(4 * (16.0/48.0))
            .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }

    private var trafficLightImage: Image {
        let scale = 16.0 / 35.0
        let view = HStack(spacing: 3 * scale) {
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
        .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }
    
    private var smallTrafficLightImage: Image {
        let scale = 16.0 / 24.0
        let view = HStack(spacing: 2 * scale) {
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
        .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }
    
    private var trafficLightVerticalImage: Image {
        let scale = 16.0 / 35.0
        let view = VStack(spacing: 3 * scale) {
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
        .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }
    
    private var smallTrafficLightVerticalImage: Image {
        let scale = 16.0 / 24.0
        let view = VStack(spacing: 2 * scale) {
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
        .frame(width: 16, height: 16, alignment: .center)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 16, height: 16))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 16, height: 16), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 16, height: 16)))
    }
    
    @ViewBuilder
    private func previewIcon(for style: IconStyle) -> some View {
        switch style {
        case .padlock:
            padlockPreviewImage
                .resizable()
                .frame(width: 16, height: 16)
        case .dot:
            dotImage
                .resizable()
                .frame(width: 16, height: 16)
        case .largeRing:
            largeRingImage
                .resizable()
                .frame(width: 16, height: 16)
        case .trafficLight:
            trafficLightImage
                .resizable()
                .frame(width: 16, height: 16)
        case .trafficLightVertical:
            trafficLightVerticalImage
                .resizable()
                .frame(width: 16, height: 16)
        case .smallTrafficLight:
            smallTrafficLightImage
                .resizable()
                .frame(width: 16, height: 16)
        case .smallTrafficLightVertical:
            smallTrafficLightVerticalImage
                .resizable()
                .frame(width: 16, height: 16)
        }
    }

    var body: some View {
        TabView {
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ロック対象ボタン")
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Toggle(isOn: Binding(
                                    get: { eventManager.enabledButtonRawValues.contains(MouseButton.left.rawValue) },
                                    set: { isOn in
                                        if isOn {
                                            eventManager.enabledButtonRawValues.insert(MouseButton.left.rawValue)
                                        } else {
                                            eventManager.enabledButtonRawValues.remove(MouseButton.left.rawValue)
                                        }
                                    }
                                )) {
                                    Text("左")
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .toggleStyle(.checkbox)
                                .environment(\.layoutDirection, systemLayoutDirection)
                                
                                Toggle(isOn: Binding(
                                    get: { eventManager.enabledButtonRawValues.contains(MouseButton.middle.rawValue) },
                                    set: { isOn in
                                        if isOn {
                                            eventManager.enabledButtonRawValues.insert(MouseButton.middle.rawValue)
                                        } else {
                                            eventManager.enabledButtonRawValues.remove(MouseButton.middle.rawValue)
                                        }
                                    }
                                )) {
                                    Text("ホイール")
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .toggleStyle(.checkbox)
                                .environment(\.layoutDirection, systemLayoutDirection)
                                
                                Toggle(isOn: Binding(
                                    get: { eventManager.enabledButtonRawValues.contains(MouseButton.right.rawValue) },
                                    set: { isOn in
                                        if isOn {
                                            eventManager.enabledButtonRawValues.insert(MouseButton.right.rawValue)
                                        } else {
                                            eventManager.enabledButtonRawValues.remove(MouseButton.right.rawValue)
                                        }
                                    }
                                )) {
                                    Text("右")
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .toggleStyle(.checkbox)
                                .environment(\.layoutDirection, systemLayoutDirection)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        }
                        Text("ドラッグロックを使用するマウスボタンを選択します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Picker(selection: $eventManager.lockType) {
                        ForEach(LockType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    } label: {
                        Text("ロック方法")
                        Text("ドラッグロックを開始する方法を選択します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .pickerStyle(.radioGroup)
                    
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
                    
                    Picker(selection: $eventManager.pointerIconStyle) {
                        Section("シングルインジケーター") {
                            Label { Text("南京錠") } icon: { previewIcon(for: .padlock) }.tag(IconStyle.padlock)
                            Label { Text("ドット") } icon: { previewIcon(for: .dot) }.tag(IconStyle.dot)
                            Label { Text("大きなリング") } icon: { previewIcon(for: .largeRing) }.tag(IconStyle.largeRing)
                        }
                        
                        Section("マルチインジケーター") {
                            Label { Text("信号機（横）") } icon: { previewIcon(for: .trafficLight) }.tag(IconStyle.trafficLight)
                            Label { Text("信号機（縦）") } icon: { previewIcon(for: .trafficLightVertical) }.tag(IconStyle.trafficLightVertical)
                            Label { Text("小さな信号機（横）") } icon: { previewIcon(for: .smallTrafficLight) }.tag(IconStyle.smallTrafficLight)
                            Label { Text("小さな信号機（縦）") } icon: { previewIcon(for: .smallTrafficLightVertical) }.tag(IconStyle.smallTrafficLightVertical)
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
                        Picker(selection: $eventManager.soundStyle) {
                            ForEach(SoundStyle.allCases, id: \.self) { style in
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
                        .foregroundStyle(.secondary)
                        .disabled(!eventManager.isSoundEnabled)
                        .help("現在のサウンドをプレビュー再生します。")
                    }
                    
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
            
            // 情報タブ
            InfoView()
                .tabItem {
                    Label("情報", systemImage: "info.circle")
                }
        }
        .navigationTitle("DragLocker 設定")
        .onAppear {
            runningApplications = NSWorkspace.shared.runningApplications
        }
        .onChange(of: lockDelay) { _, newValue in
            eventManager.lockDelay = newValue
        }
        .onDisappear {
            // 設定画面を閉じるときにメモリを整理
            SoundManager.shared.cleanupExcept(activeStyle: eventManager.soundStyle)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(EventManager())
        .frame(width: 450, height: 350)
}
