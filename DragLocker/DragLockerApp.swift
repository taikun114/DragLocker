import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: App launched, hasCompletedOnboarding = \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
        EventManager.shared.start()

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            setupOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        CursorManager.shared.hideCustomCursor()
    }

    private func setupOnboarding() {
        NSApplication.shared.setActivationPolicy(.regular)
        EventManager.shared.pauseForOnboarding()

        let onboardingView = OnboardingView { [weak self] in
            self?.completeOnboarding()
        }
        .environmentObject(EventManager.shared)

        let hostingView = NSHostingView(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // ウィンドウサイズを固定し、コンテンツによる変動を防ぐ
        window.setContentSize(NSSize(width: 300, height: 400))
        window.minSize = NSSize(width: 300, height: 400)
        window.maxSize = NSSize(width: 300, height: 400)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // ツールバーを追加してタイトルバーを大きく（高く）する
        let toolbar = NSToolbar()
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    func completeOnboarding() {
        print("DEBUG: completeOnboarding() called")
        print("DEBUG: UserDefaults before set = \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")

        // UserDefaultsに保存してディスクに即時同期
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.synchronize()
        print("DEBUG: UserDefaults after set = \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")

        // デリゲートを外してwindowWillCloseによるterminate()を防ぐ
        onboardingWindow?.delegate = nil

        // ウィンドウを画面から非表示にする
        onboardingWindow?.orderOut(nil)
        print("DEBUG: Window ordered out")

        // レンダリングパイプラインが解放されるのを待ってから破棄
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            print("DEBUG: Async block executing")
            self?.onboardingWindow?.contentView = nil
            self?.onboardingWindow = nil
            print("DEBUG: Window cleaned up")

            EventManager.shared.resumeFromOnboarding()
            print("DEBUG: resumeFromOnboarding called, isEnabled = \(EventManager.shared.isEnabled)")

            // @AppStorageがMenuBarExtraを挿入する時間を確保してからDockアイコンを非表示にする
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("DEBUG: Setting activation policy to .accessory")
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == onboardingWindow else { return }

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            NSApplication.shared.terminate(nil)
        }
    }
}

@main
struct DragLockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var eventManager = EventManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
            .disabled(!hasCompletedOnboarding)
            
            Divider()
            
            // 設定画面を開くリンク
            SettingsLink {
                Label("設定...", systemImage: "gear")
            }
            .disabled(!hasCompletedOnboarding)
            
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
