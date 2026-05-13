import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BehaviorSettingsTab: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.colorScheme) var colorScheme

    @State private var isShowingSystemOverlayHelpPopover = false

    private var appListDescription: LocalizedStringKey {
        switch eventManager.appListMode {
        case .include:
            return "このモードでは、リスト内に追加したアプリでのみドラッグロックするようにします。"
        case .exclude:
            return "このモードでは、リスト内に追加したアプリを検出されないように無視するか、ドラッグロックしないように除外します。"
        }
    }

    private var controlCenterDisplayName: String {
        AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: "com.apple.controlcenter")?.name ?? "Control Center"
    }

    private var osdUIHelperDisplayName: String {
        AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: "com.apple.OSDUIHelper")?.name ?? "OSDUIHelper"
    }

    private var dockDisplayName: String {
        AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: "com.apple.dock")?.name ?? "Dock"
    }

    private var listModePicker: some View {
        Picker(selection: $eventManager.appListMode) {
            ForEach(AppListMode.allCases, id: \.self) { mode in
                Text(mode.localizedName).tag(mode)
            }
        } label: {
            Text("リストモード")
            Text(appListDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityHint(Text(appListDescription))
        .pickerStyle(.menu)
    }

    private var appExclusionAndLimitationListView: some View {
        AppExclusionAndLimitationListView(
            bundleIdentifiers: $eventManager.appExclusionAndLimitationIdentifiers,
            accessibilityLabel: eventManager.appListMode == .exclude ? 
                String(localized: "無視または除外するアプリリスト", comment: "アプリリストのアクセシビリティラベル") : 
                String(localized: "限定するアプリリスト", comment: "アプリリストのアクセシビリティラベル")
        )
    }

    var body: some View {
        Form {
            Section {
                listModePicker
                appExclusionAndLimitationListView
            } header: {
                Text("アプリの除外と限定", comment: "アプリフィルタリングセクションのヘッダー")
            } footer: {
                HStack {
                    Spacer()
                    Button {
                        isShowingSystemOverlayHelpPopover = true
                    } label: {
                        Label("システムオーバーレイについて", systemImage: "square.stack.3d.forward.dottedline.fill")
                    }
                    .offset(x: {
                        if #available(macOS 26.0, *) {
                            return 10
                        } else {
                            return 0
                        }
                    }())
                    .popover(isPresented: $isShowingSystemOverlayHelpPopover, arrowEdge: .trailing) {
                        SystemOverlayHelpPopover()
                            .environmentObject(eventManager)
                    }
                }
            }
            
            Section {
                if #unavailable(macOS 26.0) {
                    Toggle(isOn: $eventManager.isLaunchpadExcluded) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launchpad")
                                Text("\(dockDisplayName)、レイヤー\("27 / 29")、\(Text("除外"))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "square.grid.3x2")
                                .frame(width: 24)
                        }
                    }
                }
                Toggle(isOn: $eventManager.isDockLayer18Ignored) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("デスクトップを表示 / Mission Control")
                            Text("\(dockDisplayName)、レイヤー\("18")、\(Text("無視"))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.3.group")
                            .frame(width: 24)
                    }
                }
                Toggle(isOn: $eventManager.isOSDExcluded) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("音量・明るさOSD")
                            Group {
                                if #available(macOS 26.0, *) {
                                    Text("\(controlCenterDisplayName)、レイヤー\("2005")、\(Text("除外"))")
                                } else {
                                    Text("\(osdUIHelperDisplayName)、レイヤー\("2005")、\(Text("除外"))")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .frame(width: 24)
                    }
                }
            } header: {
                Text("特定のシステムオーバーレイを無視または除外")
            }

            Section {
                PerAppSettingListView(perAppSettings: $eventManager.perAppSettings)
            } header: {
                Text("アプリごとの動作", comment: "アプリごとの動作設定セクションのヘッダー")
            } footer: {
                Text("各アプリをダブルクリックすることで設定画面を開くことができます。", comment: "アプリごとの動作設定セクションのフッター")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .onChange(of: colorScheme) { _, _ in
            AppExclusionAndLimitationDisplayResolver.shared.clearCache()
        }
    }
}

private struct SystemOverlayItem: Identifiable {
    var id: String { path }
    let description: LocalizedStringKey
    let path: String
    let bundleIdentifier: String?
    
    // パスから実行ファイル名（プロセス名）を動的に取得
    var processName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
    
    // システムから解決された表示名を取得（フォールバックはプロセス名）
    var displayName: String {
        AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: bundleIdentifier ?? path)?.name ?? processName
    }
}

struct SystemOverlayHelpPopover: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.colorScheme) var colorScheme
    
    private var overlayItems: [SystemOverlayItem] {
        let items = [
            SystemOverlayItem(
                description: spotlightDescription,
                path: "/System/Library/CoreServices/Spotlight.app/Contents/MacOS/Spotlight",
                bundleIdentifier: "com.apple.Spotlight"
            ),
            SystemOverlayItem(
                description: "アクセシビリティキーボードやスイッチコントロールなどのアクセシビリティオーバーレイ",
                path: "/System/Library/Input Methods/Assistive Control.app/Contents/MacOS/Assistive Control",
                bundleIdentifier: "com.apple.inputmethod.AssistiveControl"
            ),
            SystemOverlayItem(
                description: controlCenterDescription,
                path: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
                bundleIdentifier: "com.apple.controlcenter"
            ),
            SystemOverlayItem(
                description: dockDescription,
                path: "/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock",
                bundleIdentifier: "com.apple.dock"
            ),
            SystemOverlayItem(
                description: "Dockアイコン上のメニュー",
                path: "/System/Library/CoreServices/Dock.app/Contents/XPCServices/DockHelper.xpc/Contents/MacOS/DockHelper",
                bundleIdentifier: "com.apple.dock.helper"
            ),
            SystemOverlayItem(
                description: "アプリケーションの強制終了ウィンドウなど",
                path: "/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow",
                bundleIdentifier: "com.apple.loginwindow"
            ),
            SystemOverlayItem(
                description: "キャプションパネル",
                path: "/System/Library/CoreServices/VoiceOver.app/Contents/MacOS/VoiceOver",
                bundleIdentifier: "com.apple.VoiceOver"
            ),
            SystemOverlayItem(
                description: "ピクチャインピクチャウィンドウ",
                path: "/System/Library/CoreServices/PIPAgent.app/Contents/MacOS/PIPAgent",
                bundleIdentifier: "com.apple.PIPAgent"
            ),
            SystemOverlayItem(
                description: "絵文字と記号、文字ビューアなど",
                path: "/System/Library/Input Methods/CharacterPalette.app/Contents/MacOS/CharacterPalette",
                bundleIdentifier: "com.apple.CharacterPaletteIM"
            ),
            SystemOverlayItem(
                description: "クイックメモ",
                path: "/System/Library/Frameworks/PaperKit.framework/Contents/LinkedNotesUIService.app/Contents/MacOS/LinkedNotesUIService",
                bundleIdentifier: "com.apple.LinkedNotesUIService"
            )
        ]
        
        return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    private var dockDescription: LocalizedStringKey {
        if #available(macOS 26.0, *) {
            return "デスクトップを表示、Mission Controlなど"
        } else {
            return "Launchpad、デスクトップを表示、Mission Controlなど"
        }
    }
    
    private var spotlightDescription: LocalizedStringKey {
        if #available(macOS 26.0, *) {
            return "Spotlight検索、アプリピッカーなど"
        } else {
            return "Spotlight検索など"
        }
    }
    
    private var controlCenterDescription: LocalizedStringKey {
        if #available(macOS 26.0, *) {
            return "コントロールセンター、メニューバーアイテム、音量や明るさのOSDなど"
        } else {
            return "コントロールセンターなど"
        }
    }
    
    private var footerDescription: LocalizedStringKey {
        if #available(macOS 26.0, *) {
            return "コンテキストメニューは各アプリのプロセスが所有しているため、そのアプリを除外することでコンテキストメニューも除外されます。\nなお、システムの制約によりDock自体や通知センターを除外することはできません。"
        } else {
            return "コンテキストメニューやメニューバーアイテム（コントロールセンターに含まれるもの以外）は各アプリのプロセスが所有しているため、そのアプリを除外することでそれらも除外されます。\nなお、システムの制約によりDock自体や通知センターを除外することはできません。"
        }
    }
    
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("システムオーバーレイについて")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("システムオーバーレイを除外したい場合、オーバーレイを管理しているプロセスを除外する必要があります。\n一般的なオーバーレイプロセスは以下の通りです。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var footerBar: some View {
        Text(footerDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var itemsListView: some View {
        VStack(spacing: 12) {
            ForEach(overlayItems) { item in
                SystemOverlayItemRow(item: item)
                if item.id != overlayItems.last?.id {
                    Divider()
                        .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if #available(macOS 26.0, *) {
            ScrollView {
                itemsListView
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                headerBar
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                footerBar
            }
        } else {
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    itemsListView
                }
                footerBar
            }
        }
    }
    
    var body: some View {
        contentView
            .frame(width: 350, height: 400)
    }
}

private struct SystemOverlayItemRow: View {
    @EnvironmentObject var eventManager: EventManager
    let item: SystemOverlayItem
    
    var isAdded: Bool {
        if let bid = item.bundleIdentifier, eventManager.appExclusionAndLimitationIdentifiers.contains(bid) {
            return true
        }
        return eventManager.appExclusionAndLimitationIdentifiers.contains(item.path)
    }
    
    var body: some View {
        let appInfo = AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: item.bundleIdentifier ?? item.path)
        
        return HStack(alignment: .top, spacing: 8) {
            if let icon = appInfo?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer(minLength: 0)
            
            if isAdded {
                Button(action: {}) {
                    Label("追加済み", systemImage: "checkmark")
                }
                .disabled(true)
                .buttonStyle(.bordered)
                .help(String(localized: "\(item.displayName)はすでに\(eventManager.appListMode == .exclude ? "除外するアプリ" : "限定するアプリ")リストに追加されています。", comment: "システムオーバーレイ追加ボタンのツールチップ（追加済み）"))
            } else {
                Button(action: {
                    // バンドルIDがある場合は優先的に使用、なければパスを使用
                    eventManager.addAppExclusionAndLimitation(bundleIdentifier: item.bundleIdentifier ?? item.path)
                }) {
                    Label("追加", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .help(String(localized: "\(eventManager.appListMode == .exclude ? "除外するアプリ" : "限定するアプリ")リストに\(item.displayName)を追加します。", comment: "システムオーバーレイ追加ボタンのツールチップ（追加）"))
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    BehaviorSettingsTab()
        .environmentObject(EventManager.shared)
        .frame(width: 450, height: 450)
}
  
