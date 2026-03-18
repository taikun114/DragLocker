import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @AppStorage("lockDelay") private var lockDelay: Double = 1.0
    
    var body: some View {
        Form {
            Section(header: Text("一般")) {
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

                Toggle(isOn: Binding(
                    get: { eventManager.isIconEnabled },
                    set: { eventManager.isIconEnabled = $0 }
                )) {
                    Text("アイコンをポインタ付近に表示")
                    Text("ドラッグロックされている間、マウスポインタ付近にアイコンを表示します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: Binding(
                    get: { eventManager.isSoundEnabled },
                    set: { eventManager.isSoundEnabled = $0 }
                )) {
                    Text("サウンドを再生")
                    Text("ドラッグロックされた時と解除されたときにサウンドを再生します。")
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
        .frame(width: 400, height: 350)
}
