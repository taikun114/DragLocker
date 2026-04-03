import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初期化とアクセシビリティ権限のチェック開始
        EventManager.shared.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // アプリ終了時に確実にカスタムカーソルを解除する
        CursorManager.shared.hideCustomCursor()
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
                    eventManager.isEnabled ? "DragLocker: 動作中" : "DragLocker: 一時停止中",
                    systemImage: eventManager.isEnabled ? "play.fill" : "pause.fill"
                )
                .labelStyle(.titleAndIcon)
            }
            
            // 一時的にロック検知を無効化・有効化する切り替えボタン
            Button(action: {
                eventManager.toggleEnabled()
            }) {
                Label(
                    eventManager.isEnabled ? "ドラッグロックを一時停止" : "ドラッグロックを再開",
                    systemImage: eventManager.isEnabled ? "pause" : "play"
                )
                .labelStyle(.titleAndIcon)
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
            if !eventManager.isEnabled {
                Image("MenuBarIcon_Paused")
            } else {
                Image(eventManager.isLocked ? "MenuBarIcon_Locked" : "MenuBarIcon")
            }
        }
        
        // 設定画面のWindow定義
        Settings {
            SettingsView()
                .environmentObject(eventManager)
                .frame(width: 450, height: 350)
        }
    }
}
