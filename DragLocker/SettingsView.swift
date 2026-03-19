import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @AppStorage("lockDelay") private var lockDelay: Double = 1.0
    @State private var hoverTask: Task<Void, Never>? = nil
    
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
                
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 8) {
                        Slider(value: $lockDelay, in: 0.2...3.0, step: 0.1) {
                            Text("ロックまでの時間")
                        }
                        Text(String(format: "%.1f 秒", lockDelay))
                            .foregroundStyle(.secondary)
                    }
                    Text("ドラッグロック開始までクリックし続ける時間を設定します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                            Text(style.rawValue)
                                .tag(style)
                                .onHover { isHovering in
                                    if isHovering {
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
                        Text(String(format: "%.0f %%", eventManager.soundVolume * 100))
                            .foregroundStyle((!eventManager.isSoundEnabled || eventManager.soundStyle == .system) ? .tertiary : .secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                    Text("カスタムサウンドの再生音量を調整します。")
                        .font(.subheadline)
                        .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .secondary : .tertiary)
                }
                
                Toggle(isOn: $eventManager.isSoundInverted) {
                    Text("サウンドを反転")
                        .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .primary : .secondary)
                    Text("ロック時と解除時のサウンドを入れ替えます。")
                        .font(.subheadline)
                        .foregroundStyle(eventManager.isSoundEnabled && eventManager.soundStyle != .system ? .secondary : .tertiary)
                }
                .disabled(!eventManager.isSoundEnabled || eventManager.soundStyle == .system)
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
            }
        }
        .formStyle(.grouped)
        .navigationTitle("DragLocker 設定")
        .onChange(of: lockDelay) { _, newValue in
            eventManager.lockDelay = newValue
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(EventManager())
        .frame(width: 400, height: 500)
}
