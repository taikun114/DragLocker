import SwiftUI

struct PerAppSettingEditorView: View {
    @EnvironmentObject var eventManager: EventManager
    @Binding var setting: PerAppSetting
    @Environment(\.dismiss) var dismiss
    
    @State private var draftSetting: PerAppSetting
    
    init(setting: Binding<PerAppSetting>) {
        self._setting = setting
        self._draftSetting = State(initialValue: setting.wrappedValue)
    }
    
    // アプリ情報の解決
    private var resolvedInfo: ResolvedAppExclusionAndLimitationInfo? {
        AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: draftSetting.bundleIdentifier)
    }
    
    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                content
                    .safeAreaBar(edge: .top) {
                        header
                    }
                    .safeAreaBar(edge: .bottom) {
                        footer
                    }
                    .scrollEdgeEffectStyle(.soft, for: .all)
            } else {
                content
                    .safeAreaInset(edge: .top, spacing: 0) {
                        header
                            .background(.ultraThinMaterial)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        footer
                            .background(.ultraThinMaterial)
                    }
            }
        }
        .frame(width: 450, height: 400)
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            if let icon = resolvedInfo?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(resolvedInfo?.name ?? draftSetting.bundleIdentifier)
                    .font(.headline)
                Text(draftSetting.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var footer: some View {
        HStack {
            if #available(macOS 26.0, *) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Label("キャンセル", systemImage: "xmark")
                }
                .controlSize(.large)
                .buttonStyle(.glass)
                .accessibilityHint("変更を保存せずに閉じます。")
            } else {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Label("キャンセル", systemImage: "xmark")
                }
                .controlSize(.large)
                .accessibilityHint("変更を保存せずに閉じます。")
            }
            
            Spacer()
            
            if #available(macOS 26.0, *) {
                Button(role: .confirm, action: saveAndDismiss) {
                    Label("完了", systemImage: "checkmark")
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
            } else {
                Button(action: saveAndDismiss) {
                    Label("完了", systemImage: "checkmark")
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    @State private var hoverTask: Task<Void, Never>? = nil
    
    private func previewIcon(for style: IconStyle) -> some View {
        style.previewImage(eventManager: eventManager)
            .frame(width: 16, height: 16)
            .fixedSize()
            .id(style == .custom ? (eventManager.customIconPath ?? "custom_none") : style.rawValue)
    }

    private func saveAndDismiss() {
        setting = draftSetting
        dismiss()
    }
    
    private var activeSetting: PerAppSetting {
        var resolved = draftSetting
        
        // 依存関係を考慮した解決
        let currentLockType = !draftSetting.overrides.contains("lockMethod") ? eventManager.lockType : draftSetting.lockType
        let isIconActive = !draftSetting.overrides.contains("iconEnabled") ? eventManager.isIconEnabled : draftSetting.isIconEnabled
        let isSoundActive = !draftSetting.overrides.contains("soundEnabled") ? eventManager.isSoundEnabled : draftSetting.isSoundEnabled

        if !draftSetting.overrides.contains("mouseButtons") { resolved.enabledButtonRawValues = eventManager.enabledButtonRawValues }
        if !draftSetting.overrides.contains("lockMethod") { resolved.lockType = eventManager.lockType }
        
        if !draftSetting.overrides.contains("lockDelay") || !currentLockType.supportsTime { 
            resolved.lockDelay = eventManager.lockDelay 
        }
        if !draftSetting.overrides.contains("lockDistance") || !currentLockType.supportsDistance { 
            resolved.lockDistance = eventManager.lockDistance 
        }
        
        if !draftSetting.overrides.contains("iconEnabled") { resolved.isIconEnabled = eventManager.isIconEnabled }
        if !draftSetting.overrides.contains("iconAnimation") || !isIconActive { 
            resolved.iconAnimation = eventManager.iconAnimation 
        }
        
        if !draftSetting.overrides.contains("soundEnabled") { resolved.isSoundEnabled = eventManager.isSoundEnabled }
        if !draftSetting.overrides.contains("soundVolume") || !isSoundActive { 
            resolved.soundVolume = eventManager.soundVolume 
        }
        if !draftSetting.overrides.contains("soundInverted") || !isSoundActive { 
            resolved.isSoundInverted = eventManager.isSoundInverted 
        }
        
        // オフセット、スケール、不透明度は常に最新のグローバル設定を参照するため
        // 個別設定への反映は不要（常に同期される）
        
        return resolved
    }
    
    private var content: some View {
        Form {
            Section("一般") {
                overrideRow(key: "mouseButtons") {
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
                }
                
                overrideRow(key: "lockMethod") {
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
                }
                
                let isTimeEnabled = activeSetting.lockType == .time || activeSetting.lockType == .both
                overrideRow(key: "lockDelay", isDependencyMet: isTimeEnabled) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 8) {
                            Slider(value: $draftSetting.lockDelay, in: 0.2...3.0, step: 0.1) {
                                Text("ロックまでの時間")
                                    .foregroundStyle(isTimeEnabled ? .primary : .secondary)
                            }
                            .accessibilityValue("\(activeSetting.lockDelay, format: .number.precision(.fractionLength(1))) 秒")
                            .accessibilityHint("ドラッグロック開始までクリックし続ける時間を設定します。")
                            Text("\(activeSetting.lockDelay, format: .number.precision(.fractionLength(1))) 秒")
                                .monospacedDigit()
                                .foregroundStyle(isTimeEnabled ? .secondary : .tertiary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Text("ドラッグロック開始までクリックし続ける時間を設定します。")
                            .font(.subheadline)
                            .foregroundStyle(isTimeEnabled ? .secondary : .tertiary)
                    }
                }
                
                let isDistanceEnabled = activeSetting.lockType == .distance || activeSetting.lockType == .both
                overrideRow(key: "lockDistance", isDependencyMet: isDistanceEnabled) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 8) {
                            Slider(value: $draftSetting.lockDistance, in: 10...500, step: 10) {
                                Text("ロックまでの距離")
                                    .foregroundStyle(isDistanceEnabled ? .primary : .secondary)
                            }
                            .accessibilityValue("\(activeSetting.lockDistance, format: .number.precision(.fractionLength(0))) px")
                            .accessibilityHint("ドラッグロック開始までドラッグし続ける距離を設定します。")
                            Text("\(activeSetting.lockDistance, format: .number.precision(.fractionLength(0))) px")
                                .monospacedDigit()
                                .foregroundStyle(isDistanceEnabled ? .secondary : .tertiary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Text("ドラッグロック開始までドラッグし続ける距離を設定します。")
                            .font(.subheadline)
                            .foregroundStyle(isDistanceEnabled ? .secondary : .tertiary)
                    }
                }
            }
            
            Section("アイコン") {
                overrideRow(key: "iconEnabled") {
                    Toggle(isOn: $draftSetting.isIconEnabled) {
                        Text("アイコンをポインタ付近に表示")
                        Text("ドラッグロックされている間、マウスポインタ付近にアイコンを表示します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHint("ドラッグロックされている間、マウスポインタ付近にアイコンを表示します。")
                }
                
                let isIconActive = activeSetting.isIconEnabled
                
                overrideRow(key: "pointerIconStyle", isDependencyMet: isIconActive) {
                    Picker(selection: $draftSetting.pointerIconStyle) {
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
                            .foregroundStyle(isIconActive ? .primary : .secondary)
                        Text(draftSetting.pointerIconStyle == .custom ? 
                             "ドラッグロック中にマウスポインタ付近に表示されるアイコンのスタイルを選択します。\nカスタムアイコンはグローバル設定で指定されているものが使用されます。" : 
                             "ドラッグロック中にマウスポインタ付近に表示されるアイコンのスタイルを選択します。")
                            .font(.subheadline)
                            .foregroundStyle(isIconActive ? .secondary : .tertiary)
                    }
                    .accessibilityHint("ドラッグロック中にマウスポインタ付近に表示されるアイコンのスタイルを選択します。")
                    .labelStyle(.titleAndIcon)
                    .id(eventManager.customIconPath ?? "custom_icon_empty")
                }
                
                overrideRow(key: "iconAnimation", isDependencyMet: isIconActive) {
                    Picker(selection: $draftSetting.iconAnimation) {
                        Text(IconAnimation.default.localizedName).tag(IconAnimation.default)
                        Divider()
                        ForEach(IconAnimation.allCases.filter { $0 != .default }, id: \.self) { animation in
                            Text(animation.localizedName).tag(animation)
                        }
                    } label: {
                        Text("アニメーション")
                            .foregroundStyle(isIconActive ? .primary : .secondary)
                        Text("アイコン表示時と非表示時に適用されるアニメーションを選択します。")
                            .font(.subheadline)
                            .foregroundStyle(isIconActive ? .secondary : .tertiary)
                    }
                    .accessibilityHint("アイコン表示時と非表示時に適用されるアニメーションを選択します。")
                }
            }
            
            Section("サウンド") {
                overrideRow(key: "soundEnabled") {
                    Toggle(isOn: $draftSetting.isSoundEnabled) {
                        Text("サウンドを再生")
                        Text("ドラッグロックされたときと解除されたときにサウンドを再生します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHint("ドラッグロックされたときと解除されたときにサウンドを再生します。")
                }
                
                let isSoundActive = activeSetting.isSoundEnabled
                
                overrideRow(key: "soundStyle", isDependencyMet: isSoundActive) {
                    HStack(alignment: .top) {
                        Picker(selection: $draftSetting.soundStyle) {
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
                                                    SoundManager.shared.preview(style: style, volume: draftSetting.soundVolume, isInverted: draftSetting.isSoundInverted)
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
                                                SoundManager.shared.preview(style: .custom, volume: draftSetting.soundVolume, isInverted: draftSetting.isSoundInverted)
                                            }
                                        }
                                    } else {
                                        hoverTask?.cancel()
                                    }
                                }
                        } label: {
                            Text("サウンドスタイル")
                                .foregroundStyle(isSoundActive ? .primary : .secondary)
                            Text(draftSetting.soundStyle == .custom ? 
                                 "再生するサウンドを選択します。マウスホバーでサウンドをプレビューできます。\nカスタムサウンドはグローバル設定で指定されているものが使用されます。" : 
                                 "再生するサウンドを選択します。マウスホバーでサウンドをプレビューできます。")
                                .font(.subheadline)
                                .foregroundStyle(isSoundActive ? .secondary : .tertiary)
                        }
                        .pickerStyle(.menu)
                        
                        Button {
                            SoundManager.shared.loadSound(style: draftSetting.soundStyle)
                            SoundManager.shared.preview(style: draftSetting.soundStyle, volume: draftSetting.soundVolume, isInverted: draftSetting.isSoundInverted)
                        } label: {
                            Label("サウンドをプレビュー", systemImage: "play.circle")
                                .font(.title3)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(isSoundActive ? .secondary : .tertiary)
                        .disabled(!isSoundActive)
                        .help("現在のサウンドをプレビュー再生します。")
                    }
                }
                
                overrideRow(key: "soundVolume", isDependencyMet: isSoundActive) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 8) {
                            Slider(value: $draftSetting.soundVolume, in: 0.0...1.0, step: 0.05) {
                                Text("サウンドの音量")
                                    .foregroundStyle(isSoundActive && activeSetting.soundStyle != .system ? .primary : .secondary)
                            }
                            .disabled(activeSetting.soundStyle == .system)
                            .accessibilityValue(Text(activeSetting.soundVolume, format: .percent.precision(.fractionLength(0))))
                            .accessibilityHint("カスタムサウンドの再生音量を調整します。")
                            Text(activeSetting.soundVolume, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle((!isSoundActive || activeSetting.soundStyle == .system) ? .tertiary : .secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Text("カスタムサウンドの再生音量を調整します。")
                            .font(.subheadline)
                            .foregroundStyle(isSoundActive && activeSetting.soundStyle != .system ? .secondary : .tertiary)
                    }
                }
                
                overrideRow(key: "soundInverted", isDependencyMet: isSoundActive) {
                    Toggle(isOn: $draftSetting.isSoundInverted) {
                        Text("サウンドを反転")
                            .foregroundStyle(isSoundActive && activeSetting.soundStyle != .system ? .primary : .secondary)
                        Text("ドラッグロックされたときと解除されたときに再生されるサウンドを入れ替えます。")
                            .font(.subheadline)
                            .foregroundStyle(isSoundActive && activeSetting.soundStyle != .system ? .secondary : .tertiary)
                    }
                    .disabled(activeSetting.soundStyle == .system)
                    .accessibilityHint("ドラッグロックされたときと解除されたときに再生されるサウンドを入れ替えます。")
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Helper Views
    
    private func overrideToggle(for key: String, isDependencyMet: Bool = true) -> some View {
        let localizedKeyName: String
        switch key {
        case "mouseButtons": localizedKeyName = String(localized: "ロック対象ボタン")
        case "lockMethod": localizedKeyName = String(localized: "ロック方法")
        case "lockDelay": localizedKeyName = String(localized: "ロックまでの時間")
        case "lockDistance": localizedKeyName = String(localized: "ロックまでの距離")
        case "iconEnabled": localizedKeyName = String(localized: "アイコンをポインタ付近に表示")
        case "pointerIconStyle": localizedKeyName = String(localized: "アイコンスタイル")
        case "iconAnimation": localizedKeyName = String(localized: "アニメーション")
        case "soundEnabled": localizedKeyName = String(localized: "サウンドを再生")
        case "soundStyle": localizedKeyName = String(localized: "サウンドスタイル")
        case "soundVolume": localizedKeyName = String(localized: "サウンドの音量")
        case "soundInverted": localizedKeyName = String(localized: "サウンドを反転")
        default: localizedKeyName = ""
        }
        
        return Toggle(String(localized: "「\(localizedKeyName)」設定を上書きする"), isOn: Binding(
            get: { draftSetting.overrides.contains(key) },
            set: { isEnabled in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isEnabled {
                        _ = draftSetting.overrides.insert(key)
                    } else {
                        _ = draftSetting.overrides.remove(key)
                        
                        // 値をグローバル設定に戻す
                        switch key {
                        case "mouseButtons":
                            draftSetting.enabledButtonRawValues = eventManager.enabledButtonRawValues
                        case "lockMethod":
                            draftSetting.lockType = eventManager.lockType
                        case "lockDelay":
                            draftSetting.lockDelay = eventManager.lockDelay
                        case "lockDistance":
                            draftSetting.lockDistance = eventManager.lockDistance
                        case "iconEnabled":
                            draftSetting.isIconEnabled = eventManager.isIconEnabled
                        case "iconAnimation":
                            draftSetting.iconAnimation = eventManager.iconAnimation
                        case "soundEnabled":
                            draftSetting.isSoundEnabled = eventManager.isSoundEnabled
                        case "soundVolume":
                            draftSetting.soundVolume = eventManager.soundVolume
                        case "soundInverted":
                            draftSetting.isSoundInverted = eventManager.isSoundInverted
                        default:
                            break
                        }
                        
                        // 依存関係のクリーンアップ
                        if key == "iconEnabled" {
                            _ = draftSetting.overrides.remove("iconAnimation")
                            draftSetting.iconAnimation = eventManager.iconAnimation
                        } else if key == "soundEnabled" {
                            _ = draftSetting.overrides.remove("soundVolume")
                            _ = draftSetting.overrides.remove("soundInverted")
                            draftSetting.soundVolume = eventManager.soundVolume
                            draftSetting.isSoundInverted = eventManager.isSoundInverted
                        } else if key == "lockMethod" {
                            let globalType = eventManager.lockType
                            if !globalType.supportsTime {
                                _ = draftSetting.overrides.remove("lockDelay")
                                draftSetting.lockDelay = eventManager.lockDelay
                            }
                            if !globalType.supportsDistance {
                                _ = draftSetting.overrides.remove("lockDistance")
                                draftSetting.lockDistance = eventManager.lockDistance
                            }
                        }
                    }
                }
            }
        ))
        .toggleStyle(.checkbox)
        .disabled(!isDependencyMet)
        .labelsHidden()
        .help("チェックを入れると、この項目のグローバル設定を上書きします。")
    }

    private func overrideRow<V: View>(key: String, isDependencyMet: Bool = true, @ViewBuilder content: @escaping () -> V) -> some View {
        let isOverridden = draftSetting.overrides.contains(key)
        
        return HStack(alignment: .top, spacing: 8) {
            overrideToggle(for: key, isDependencyMet: isDependencyMet)
            
            ZStack {
                content()
                    .disabled(!isOverridden || !isDependencyMet)
                
                if !isOverridden && isDependencyMet {
                    Rectangle()
                        .opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                _ = draftSetting.overrides.insert(key)
                            }
                        }
                }
            }
        }
    }
    
    private func mouseButtonSelection(imageName: String, title: LocalizedStringResource, button: MouseButton) -> some View {
        let isSelected = activeSetting.enabledButtonRawValues.contains(button.rawValue)
        let isOverridden = draftSetting.overrides.contains("mouseButtons")
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if draftSetting.enabledButtonRawValues.contains(button.rawValue) {
                    draftSetting.enabledButtonRawValues.remove(button.rawValue)
                } else {
                    draftSetting.enabledButtonRawValues.insert(button.rawValue)
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
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
        .disabled(!isOverridden)
        .help(Text("\(String(localized: title))ボタンをドラッグロックの対象にします。"))
    }
    
    private func methodButton(imageName: String, title: LocalizedStringResource, type: LockType) -> some View {
        let isSelected = activeSetting.lockType == type
        let isOverridden = draftSetting.overrides.contains("lockMethod")
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                draftSetting.lockType = type
                
                // 選択したタイプでサポートされない項目の上書きを消す
                if !type.supportsTime {
                    _ = draftSetting.overrides.remove("lockDelay")
                }
                if !type.supportsDistance {
                    _ = draftSetting.overrides.remove("lockDistance")
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
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
        .disabled(!isOverridden)
        .help(Text("「\(String(localized: title))」方式でドラッグロックを開始します。"))
    }
}

#Preview {
    PerAppSettingEditorView(setting: .constant(PerAppSetting(bundleIdentifier: "com.apple.Safari", eventManager: EventManager.shared)))
        .environmentObject(EventManager.shared)
}
