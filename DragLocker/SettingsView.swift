import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @AppStorage("lockDelay") private var lockDelay: Double = 1.0
    
    var body: some View {
        Form {
            Group {
                Section(header: Text("権限状態")) {
                    if !eventManager.isTrusted {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("アクセシビリティ権限が不足しています")
                                    .foregroundColor(.red)
                                    .bold()
                            }
                            
                            Text("ドラッグロックを機能させるには、システムからの許可が必要です。")
                                .font(.caption)
                            
                            Button("システムに権限を要求する") {
                                eventManager.requestAccessibilityPermissions()
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("正常に動作中（アクセス許可済み）")
                        }
                    }
                }
                
                Section(header: Text("基本設定"), footer: Text("※左クリックを指定した時間長押しするとドラッグロックが発動します。")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("ロック待機時間:")
                            Spacer()
                            Text(String(format: "%.1f 秒", lockDelay))
                                .bold()
                        }
                        
                        Slider(value: $lockDelay, in: 0.2...3.0, step: 0.1)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 350)
        .navigationTitle("DragLocker 設定")
        .onChange(of: lockDelay) { _, newValue in
            eventManager.lockDelay = newValue
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(EventManager())
}
