import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers
import Combine

enum SettingsTab: Hashable {
    case general, customization, behavior, info
}

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.layoutDirection) private var systemLayoutDirection
    @State private var selectedTab: SettingsTab
    private let shouldResetOnAppear: Bool
    
    init(initialTab: SettingsTab = .general, shouldResetOnAppear: Bool = true) {
        self._selectedTab = State(initialValue: initialTab)
        self.shouldResetOnAppear = shouldResetOnAppear
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
            
            CustomizationSettingsTab()
            
            BehaviorSettingsTab()
            
            InfoView()
                .tabItem {
                    Label("情報", systemImage: "info.circle")
                }
                .tag(SettingsTab.info)
        }
        .navigationTitle("DragLocker 設定")
        .onAppear {
            // 設定画面表示時はDockアイコンを表示する
            NSApp.setActivationPolicy(.regular)
            // アプリを前面に持ってくる
            NSApp.activate(ignoringOtherApps: true)
            // 設定画面を開くたびに「一般」タブにリセットする（プレビュー以外）
            if shouldResetOnAppear {
                selectedTab = .general
            }
        }
        .onDisappear {
            // 設定画面を閉じたらDockアイコンを非表示にする
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

#Preview("一般") {
    SettingsView(initialTab: .general, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}

#Preview("カスタマイズ") {
    SettingsView(initialTab: .customization, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}

#Preview("動作") {
    SettingsView(initialTab: .behavior, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}

#Preview("情報") {
    SettingsView(initialTab: .info, shouldResetOnAppear: false)
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}
