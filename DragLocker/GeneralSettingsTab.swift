import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers
import Combine

struct GeneralSettingsTab: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @AppStorage("lockDelay") private var lockDelay: Double = 1.0
    
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
                .accessibilityHint("Macのログイン時にDragLockerを自動で起動します。")
                
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
                
                // 時間設定
                let isTimeEnabled = eventManager.lockType == .time || eventManager.lockType == .both
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 8) {
                        Slider(value: $lockDelay, in: 0.2...3.0, step: 0.1) {
                            Text("ロックまでの時間")
                                .foregroundStyle(isTimeEnabled ? .primary : .secondary)
                        }
                        .accessibilityValue("\(lockDelay, format: .number.precision(.fractionLength(1))) 秒")
                        .accessibilityHint("ドラッグロック開始までクリックし続ける時間を設定します。")
                        Text("\(lockDelay, format: .number.precision(.fractionLength(1))) 秒")
                            .monospacedDigit()
                            .foregroundStyle(isTimeEnabled ? .secondary : .tertiary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    Text("ドラッグロック開始までクリックし続ける時間を設定します。")
                        .font(.subheadline)
                        .foregroundStyle(isTimeEnabled ? .secondary : .tertiary)
                }
                .disabled(!isTimeEnabled)
                .animation(nil, value: isTimeEnabled)
                
                // 距離設定
                let isDistanceEnabled = eventManager.lockType == .distance || eventManager.lockType == .both
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 8) {
                        Slider(value: $eventManager.lockDistance, in: 10...500, step: 10) {
                            Text("ロックまでの距離")
                                .foregroundStyle(isDistanceEnabled ? .primary : .secondary)
                        }
                        .accessibilityValue("\(eventManager.lockDistance, format: .number.precision(.fractionLength(0))) px")
                        .accessibilityHint("ドラッグロック開始までドラッグし続ける距離を設定します。")
                        Text("\(eventManager.lockDistance, format: .number.precision(.fractionLength(0))) px")
                            .monospacedDigit()
                            .foregroundStyle(isDistanceEnabled ? .secondary : .tertiary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    Text("ドラッグロック開始までドラッグし続ける距離を設定します。")
                        .font(.subheadline)
                        .foregroundStyle(isDistanceEnabled ? .secondary : .tertiary)
                }
                .disabled(!isDistanceEnabled)
                .animation(nil, value: isDistanceEnabled)
                
                // Escキー解除
                Toggle(isOn: $eventManager.isUnlockAllWithEscEnabled) {
                    Text("Escキーですべてのロックを解除")
                    Text("ドラッグロック中にEscキーを押してすべてのボタンのロックを解除します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityHint("ドラッグロック中にEscキーを押してすべてのボタンのロックを解除します。")
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
                .accessibilityHint("ドラッグロックの切り替え時にシステム通知を表示します。")
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
        .onChange(of: lockDelay) { _, newValue in
            eventManager.lockDelay = newValue
        }
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
}

#Preview {
    GeneralSettingsTab()
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}
