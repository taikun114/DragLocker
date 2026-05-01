import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers
import Combine

enum SettingsTab: String, Hashable {
    case general, customization, behavior, info
}

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.layoutDirection) private var systemLayoutDirection
    @Binding var selectedTab: SettingsTab
    
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
            // 設定画面を開くたびに「一般」タブにリセットする
            selectedTab = .general
            
            // 設定画面表示時はDockアイコンを表示する
            NSApp.setActivationPolicy(.regular)
            // アプリを前面に持ってくる
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            // 設定画面を閉じたらDockアイコンを非表示にする
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

struct SettingsView_PreviewWrapper: View {
    @State var selectedTab: SettingsTab
    
    var body: some View {
        SettingsView(selectedTab: $selectedTab)
            .environmentObject(EventManager.shared)
            .frame(width: 450, height: 450)
    }
}

#Preview("一般") {
    SettingsView_PreviewWrapper(selectedTab: .general)
}

#Preview("カスタマイズ") {
    SettingsView_PreviewWrapper(selectedTab: .customization)
}

#Preview("動作") {
    SettingsView_PreviewWrapper(selectedTab: .behavior)
}

#Preview("情報") {
    SettingsView_PreviewWrapper(selectedTab: .info)
}
