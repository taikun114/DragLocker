import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初期化とアクセシビリティ権限のチェック開始
        EventManager.shared.start()
    }
}

@main
struct DragLockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var eventManager = EventManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            // 状態表示用のラベル（クリック不可）
            HStack {
            Label(
                eventManager.isEnabled ? "DragLocker: 動作中" : "DragLocker: 停止中",
                systemImage: eventManager.isEnabled ? "checkmark.circle" : "pause.circle"
            )
            }
            
            // 一時的にロック検知を無効化・有効化する切り替えボタン
            Button(action: {
                eventManager.toggleEnabled()
            }) {
                Label(
                    eventManager.isEnabled ? "ドラッグロックを無効化" : "ドラッグロックを有効化",
                    systemImage: eventManager.isEnabled ? "pause" : "play"
                )
            }
            
            Divider()
            
            // 設定画面を開くリンク
            SettingsLink {
                Label("設定...", systemImage: "gear")
            }
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("終了", systemImage: "xmark")
            }
            .keyboardShortcut("q")
        } label: {
            if #available(macOS 26.0, *) {
                Image(systemName: "pointer.arrow.click.2", variableValue: eventManager.isLocked ? 1.0 : 0.0)
                    .environment(\.symbolVariants, .none)
            } else {
                Image(systemName: "cursorarrow.click.2", variableValue: eventManager.isLocked ? 1.0 : 0.0)
                    .environment(\.symbolVariants, .none)
            }
        }
        
        // 設定画面のWindow定義
        Settings {
            SettingsView()
                .environmentObject(eventManager)
        }
    }
}
