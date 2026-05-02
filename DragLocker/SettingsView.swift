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
        let customizationIcon = if #available(macOS 26.0, *) { "pointer.arrow.rays" } else { "cursorarrow.rays" }
        let behaviorIcon = if #available(macOS 26.0, *) { "pointer.arrow.and.square.on.square.dashed" } else { "cursorarrow.and.square.on.square.dashed" }
        
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
                .tag(SettingsTab.general)
            
            CustomizationSettingsTab()
                .tabItem {
                    Label("カスタマイズ", systemImage: customizationIcon)
                }
                .tag(SettingsTab.customization)
            
            BehaviorSettingsTab()
                .tabItem {
                    Label("動作", systemImage: behaviorIcon)
                }
                .tag(SettingsTab.behavior)
            
            InfoView()
                .tabItem {
                    Label("情報", systemImage: "info.circle")
                }
                .tag(SettingsTab.info)
        }
        .onAppear {
            // 設定画面を開くたびに「一般」タブにリセットする
            selectedTab = .general
            
            // アプリを前面に持ってくる
            NSApp.activate(ignoringOtherApps: true)
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
