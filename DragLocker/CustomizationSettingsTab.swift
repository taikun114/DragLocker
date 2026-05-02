import SwiftUI
import UniformTypeIdentifiers
import Combine

struct CustomizationSettingsTab: View {
    @EnvironmentObject var eventManager: EventManager
    
    @State private var hoverTask: Task<Void, Never>? = nil
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
    @State private var iconPreloadTask: Task<Void, Never>? = nil
    
    var body: some View {
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
                .accessibilityHint("ドラッグロックされている間、マウスポインタ付近にアイコンを表示します。")
                
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
                .accessibilityHint("ドラッグロック中にマウスポインタ付近に表示されるアイコンのスタイルを選択します。")
                .labelStyle(.titleAndIcon)
                .pickerStyle(.menu)
                .disabled(!eventManager.isIconEnabled)
                
                customIconSettingsView
                
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
                .accessibilityHint("アイコン表示時と非表示時に適用されるアニメーションを選択します。")
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
                .accessibilityHint("ドラッグロックされた時と解除されたときにサウンドを再生します。")
                
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
                        Label("サウンドをプレビュー", systemImage: "play.circle")
                            .font(.title3)
                    }
                    .labelStyle(.iconOnly)
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
                
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 8) {
                        Slider(value: $eventManager.soundVolume, in: 0.0...1.0, step: 0.05) {
                            Text("サウンドの音量")
                                .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .primary : .secondary)
                        }
                        .disabled(!eventManager.isSoundEnabled || eventManager.soundStyle == .system)
                        .accessibilityValue(Text(eventManager.soundVolume, format: .percent.precision(.fractionLength(0))))
                        .accessibilityHint("カスタムサウンドの再生音量を調整します。")
                        Text(eventManager.soundVolume, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle((!eventManager.isSoundEnabled || eventManager.soundStyle == .system) ? .tertiary : .secondary)
                            .frame(width: 50, alignment: .trailing)
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
                .accessibilityHint("ドラッグロックされた時と解除された時に再生されるサウンドを入れ替えます。")
            }
        }
        .formStyle(.grouped)
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
        .onDisappear {
            // 設定画面を閉じるときにメモリを整理
            SoundManager.shared.cleanupExcept(activeStyle: eventManager.soundStyle)
            hoverTask?.cancel()
            hoverTask = nil
            iconPreloadTask?.cancel()
            iconPreloadTask = nil
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
                    Label("\(title)をプレビュー", systemImage: "play.circle")
                        .font(.title3)
                }
                .labelStyle(.iconOnly)
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
                Button("選択…") {
                    selectAudioFile(index: index)
                }
                .disabled(!isEnabled || !isCustom)
                .help("カスタムサウンドとして使用するオーディオファイルを選択します。")
                .accessibilityHint("カスタムサウンドとして使用するオーディオファイルを選択します。")
                
                Button("削除…", role: .destructive) {
                    soundIndexToDelete = index
                    soundNameToDelete = displayName
                    showingDeleteSoundConfirmation = true
                }
                .disabled(!isEnabled || !isCustom || fileName == nil)
                .help("カスタムサウンドとして設定されたオーディオファイルを削除します。")
                .accessibilityHint("カスタムサウンドとして設定されたオーディオファイルを削除します。")
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private static var iconCache: [IconStyle: Image] = [:]
    
    private func getIcon(for style: IconStyle) -> Image {
        // カスタムスタイルの場合は、スケールや不透明度の変更を反映するためキャッシュせず毎回生成する
        if style == .custom {
            return generateIcon(for: .custom)
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
            if let image = eventManager.cachedCustomIconImage {
                // EventManagerのキャッシュは既にトリミング・リサイズ済み
                // 80x80相当での表示倍率を計算
                let fitScale = min(1.0, 80.0 / max(1, image.size.width), 80.0 / max(1, image.size.height))
                let contentDisplaySizeIn80 = max(image.size.width, image.size.height) * fitScale * eventManager.customIconScale
                let normalizedScale = contentDisplaySizeIn80 / 80.0
                
                view = AnyView(
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .scaleEffect(max(1.0, normalizedScale))
                        .opacity(eventManager.customIconOpacity)
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
                            if let nsImage = eventManager.cachedCustomIconImage {
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
                        Button("選択…") {
                            selectCustomIcon()
                        }
                        .disabled(eventManager.pointerIconStyle != .custom)
                        .help("カスタムアイコンとして使用する画像ファイルを選択します。")
                        .accessibilityHint("カスタムアイコンとして使用する画像ファイルを選択します。")
                        
                        Button("削除…", role: .destructive) {
                            iconNameToDelete = eventManager.customIconName ?? ""
                            showingDeleteIconConfirmation = true
                        }
                        .disabled(eventManager.pointerIconStyle != .custom || eventManager.customIconPath == nil || !eventManager.isIconEnabled)
                        .help("カスタムアイコンとして設定された画像ファイルを削除します。")
                        .accessibilityHint("カスタムアイコンとして設定された画像ファイルを削除します。")
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
                    .accessibilityValue(Text(eventManager.customIconScale, format: .percent.precision(.fractionLength(0))))
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
                    .accessibilityValue(Text(eventManager.customIconOpacity, format: .percent.precision(.fractionLength(0))))
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
                    .accessibilityValue("\(Int(eventManager.customIconXOffset))")
                    .accessibilityHint("アイコンの水平方向の表示位置を調整します。")
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
                    .accessibilityValue("\(Int(eventManager.customIconYOffset))")
                    .accessibilityHint("アイコンの垂直方向の表示位置を調整します。")
                    Text(Int(eventManager.customIconYOffset), format: .number)
                        .monospacedDigit()
                        .foregroundStyle(eventManager.isIconEnabled ? .secondary : .tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .disabled(!eventManager.isIconEnabled)
            
            HStack {
                Spacer()
                Button("リセット…") {
                    showingResetIconSettingsConfirmation = true
                }
                .disabled(!eventManager.isIconEnabled)
                .help("大きさ、不透明度、Xオフセット、Yオフセットを既定値にリセットします。")
                .accessibilityHint("大きさ、不透明度、Xオフセット、Yオフセットを既定値にリセットします。")
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
