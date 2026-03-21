import SwiftUI

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
    
    private var dotImage: Image {
        let view = ZStack(alignment: .center) {
            Circle().fill(Color.white).frame(width: 8, height: 8)
            Circle().fill(Color.black).frame(width: 6, height: 6)
        }.frame(width: 8, height: 8)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(CGSize(width: 8, height: 8))
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 8, height: 8))!
        hostingView.cacheDisplay(in: NSRect(x: 0, y: 0, width: 8, height: 8), to: bitmap)
        
        return Image(nsImage: NSImage(cgImage: bitmap.cgImage!, size: CGSize(width: 8, height: 8)))
    }

    var body: some View {
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
                            Text("\(lockDelay, specifier: "%.1f") 秒")
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
                            Text("\(eventManager.lockDistance, specifier: "%.0f") px")
                                .foregroundStyle(.secondary)
                        }
                        Text("ドラッグロック開始までドラッグし続ける距離を設定します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
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
                    Label { Text("南京錠") } icon: {
                        Image("Pointer_Locked")
                    }.tag(IconStyle.padlock)
                    
                    Label { Text("ドット") } icon: {
                        dotImage
                    }.tag(IconStyle.dot)
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
                        Text("\(eventManager.soundVolume * 100, specifier: "%.0f") %")
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

            ManagedAppSettingsSection(
                eventManager: eventManager,
                isShowingManagedAppPopover: $isShowingManagedAppPopover,
                showAllRunningApps: $showAllRunningApps,
                selectedManagedAppIds: $selectedManagedAppIds,
                runningApplications: $runningApplications,
                showingInvalidAppAlert: $showingInvalidAppAlert,
                showingClearAllManagedAppsConfirmation: $showingClearAllManagedAppsConfirmation
            )
            
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
            }
        }
        .formStyle(.grouped)
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
        .frame(width: 400, height: 500)
}
