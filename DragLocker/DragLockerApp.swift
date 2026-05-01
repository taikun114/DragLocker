import SwiftUI
import KeyboardShortcuts

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
        EventManager.shared.forceUnlock()
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
        #if DEBUG
        print("DEBUG: UserDefaults before set = \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
        #endif

        // UserDefaultsに保存してディスクに即時同期
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.synchronize()
        #if DEBUG
        print("DEBUG: UserDefaults after set = \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
        #endif

        // デリゲートを外してwindowWillCloseによるterminate()を防ぐ
        onboardingWindow?.delegate = nil

        // ウィンドウを画面から非表示にする
        onboardingWindow?.orderOut(nil)
        #if DEBUG
        print("DEBUG: Window ordered out")
        #endif

        // レンダリングパイプラインが解放されるのを待ってから破棄
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            #if DEBUG
            print("DEBUG: Async block executing")
            #endif
            self?.onboardingWindow?.contentView = nil
            self?.onboardingWindow = nil
            print("DEBUG: Window cleaned up")

            EventManager.shared.resumeFromOnboarding()
            #if DEBUG
            print("DEBUG: resumeFromOnboarding called, isEnabled = \(EventManager.shared.isEnabled)")
            #endif

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
    @State private var selectedSettingsTab: SettingsTab = .general
    
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
            .applyKeyboardShortcut(for: .toggleMonitoring)
            .disabled(!hasCompletedOnboarding)
            
            Divider()
            
            // 設定画面を開くリンク
            SettingsLink {
                Label("設定…", systemImage: "gear")
            }
            .keyboardShortcut(",")
            .disabled(!hasCompletedOnboarding)
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("終了", systemImage: "xmark")
            }
            .keyboardShortcut("q")
        } label: {
            MenuBarIconView()
        }
        
        // 設定画面のWindow定義
        Settings {
            SettingsView(selectedTab: $selectedSettingsTab)
                .environmentObject(eventManager)
                .frame(width: 450, height: 450)
        }
        .commands {
            AppCommands()
        }
    }
}

struct AppCommands: Commands {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(action: {
                AboutWindowController.show()
            }) {
                Label("DragLockerについて", systemImage: "info.circle")
            }
        }
        
        CommandGroup(replacing: .appSettings) {
            SettingsLink {
                Label("設定…", systemImage: "gear")
            }
            .keyboardShortcut(",")
            .disabled(!hasCompletedOnboarding)
        }
    }
}

struct MenuBarIconView: View {
    @ObservedObject var eventManager = EventManager.shared
    @ObservedObject var lockState = LockStateManager.shared
    
    var body: some View {
        if !eventManager.isEnabled {
            Image("MenuBarIcon_Paused")
        } else {
            Image(lockState.isLocked ? "MenuBarIcon_Locked" : "MenuBarIcon")
        }
    }
}

// MARK: - KeyboardShortcuts SwiftUI Support
extension View {
    @ViewBuilder
    func applyKeyboardShortcut(for name: KeyboardShortcuts.Name) -> some View {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name),
           let char = shortcut.keyEquivalentChar {
            self.keyboardShortcut(KeyEquivalent(char), modifiers: shortcut.swiftUIModifiers)
        } else {
            self
        }
    }
}

extension KeyboardShortcuts.Shortcut {
    @MainActor
    var keyEquivalentChar: Character? {
        // description (例: "⌃⇧⌘L") から装飾キー記号を除去して文字を取り出す
        let desc = self.description
        let symbols: Set<Character> = ["⌘", "⌥", "⇧", "⌃", "🌐"]
        let filtered = desc.filter { !symbols.contains($0) }
        return filtered.lowercased().first
    }

    var swiftUIModifiers: EventModifiers {
        var modifiers: EventModifiers = []
        let carbonFlags = self.carbonModifiers
        
        // Carbonの装飾キー定数を使用して判定
        if (carbonFlags & 0x0100) != 0 { modifiers.insert(.command) } // cmdKey
        if (carbonFlags & 0x0800) != 0 { modifiers.insert(.option) }  // optionKey
        if (carbonFlags & 0x1000) != 0 { modifiers.insert(.control) } // controlKey
        if (carbonFlags & 0x0200) != 0 { modifiers.insert(.shift) }   // shiftKey
        if (carbonFlags & 0x0400) != 0 { modifiers.insert(.capsLock) } // alphaLock / capsLock
        
        return modifiers
    }
}

class AboutWindowController: NSObject, NSWindowDelegate {
    private static var instance: AboutWindowController?
    private var window: NSWindow?
    
    static func show() {
        if let instance = instance {
            instance.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let controller = AboutWindowController()
        instance = controller
        controller.setupWindow()
    }
    
    private func setupWindow() {
        let aboutView = InfoView()
            .frame(width: 450, height: 450)
            .environmentObject(EventManager.shared)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "DragLockerについて"
        window.isReleasedWhenClosed = false // クラッシュ防止のためfalse（ARCがメモリ解放を管理する）
        window.isExcludedFromWindowsMenu = true
        window.delegate = self
        window.contentView = NSHostingView(rootView: aboutView)
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        self.window = nil // ウインドウへの参照を解除
        AboutWindowController.instance = nil // インスタンスを破棄してメモリを解放
    }
}
