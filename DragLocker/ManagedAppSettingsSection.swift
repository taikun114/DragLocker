import AppKit
import SwiftUI
import UniformTypeIdentifiers

private final class ResolvedManagedApplicationInfo {
    let name: String
    let icon: NSImage?
    
    init(name: String, icon: NSImage?) {
        self.name = name
        self.icon = icon
    }
}

private final class ManagedApplicationDisplayResolver {
    static let shared = ManagedApplicationDisplayResolver()

    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, ResolvedManagedApplicationInfo>()
    private let lock = NSLock()
    private var searchedBundleIdentifiers: Set<String> = []
    
    func clearCache() {
        lock.lock()
        cache.removeAllObjects()
        searchedBundleIdentifiers.removeAll()
        lock.unlock()
    }

    func resolvedInfo(for identifier: String) -> ResolvedManagedApplicationInfo? {
        if let cachedInfo = cache.object(forKey: identifier as NSString) {
            return cachedInfo
        }

        lock.lock()
        let hasSearched = searchedBundleIdentifiers.contains(identifier)
        lock.unlock()
        
        if hasSearched {
            return nil
        }
        
        // バンドル識別子、フルパス、または実行ファイル名で実行中のアプリを検索
        if let runningApplication = NSWorkspace.shared.runningApplications.first(where: { 
            !$0.isTerminated && ($0.bundleIdentifier == identifier || $0.executableURL?.path == identifier || $0.executableURL?.lastPathComponent == identifier)
        }) {
            var icon = runningApplication.icon
            
            // アイコンの改善を試みる
            if let exeURL = runningApplication.executableURL {
                // 親ディレクトリを遡って .app を探す (.bundle は六角形アイコンになることがあるため除外)
                if icon == nil || icon?.size.width ?? 0 <= 32 {
                    var current = exeURL.deletingLastPathComponent()
                    while current.path != "/" {
                        if current.pathExtension.lowercased() == "app" {
                            icon = NSWorkspace.shared.icon(forFile: current.path)
                            break
                        }
                        current = current.deletingLastPathComponent()
                    }
                }
                
                // それでも取れない場合は実行ファイル自体のアイコン
                if icon == nil {
                    icon = NSWorkspace.shared.icon(forFile: exeURL.path)
                }
            }

            let resolvedInfo = ResolvedManagedApplicationInfo(
                name: runningApplication.localizedName ?? identifier,
                icon: icon
            )
            store(resolvedInfo, for: identifier)
            return resolvedInfo
        }

        // バンドル識別子としてURLを解決してみる
        if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
           let resolvedInfo = resolvedInfo(from: applicationURL, fallbackName: identifier) {
            store(resolvedInfo, for: identifier)
            return resolvedInfo
        }
        
        // ファイルパスとして直接アイコンを取得してみる（識別子がフルパスの場合）
        if identifier.starts(with: "/"), fileManager.fileExists(atPath: identifier) {
            let url = URL(fileURLWithPath: identifier)
            let icon = NSWorkspace.shared.icon(forFile: identifier)
            let name = url.lastPathComponent
            let resolvedInfo = ResolvedManagedApplicationInfo(name: name, icon: icon)
            store(resolvedInfo, for: identifier)
            return resolvedInfo
        }

        if !hasSearched,
           let applicationURL = searchApplicationURLInUserApplications(bundleIdentifier: identifier),
           let resolvedInfo = resolvedInfo(from: applicationURL, fallbackName: identifier) {
            store(resolvedInfo, for: identifier)
            return resolvedInfo
        }

        lock.lock()
        searchedBundleIdentifiers.insert(identifier)
        lock.unlock()
        return nil
    }

    private func store(_ info: ResolvedManagedApplicationInfo, for bundleIdentifier: String) {
        cache.setObject(info, forKey: bundleIdentifier as NSString)
        lock.lock()
        searchedBundleIdentifiers.insert(bundleIdentifier)
        lock.unlock()
    }

    private func resolvedInfo(from applicationURL: URL, fallbackName: String) -> ResolvedManagedApplicationInfo? {
        guard let appBundle = Bundle(url: applicationURL) else { return nil }

        let resolvedName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? appBundle.localizedInfoDictionary?["CFBundleName"] as? String
            ?? appBundle.infoDictionary?["CFBundleName"] as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        return ResolvedManagedApplicationInfo(name: resolvedName, icon: icon)
    }

    private func searchApplicationURLInUserApplications(bundleIdentifier: String) -> URL? {
        let userApplicationsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: userApplicationsURL,
            includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let applicationURL as URL in enumerator {
            guard applicationURL.pathExtension == "app" else { continue }
            guard let bundle = Bundle(url: applicationURL),
                  bundle.bundleIdentifier == bundleIdentifier else {
                continue
            }
            return applicationURL
        }

        return nil
    }
}

struct ManagedAppSettingsSection: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var eventManager: EventManager

    @Binding var isShowingManagedAppPopover: Bool
    @Binding var showAllRunningApps: Bool
    @Binding var selectedManagedAppIds: Set<String>
    @Binding var runningApplications: [NSRunningApplication]
    @Binding var showingInvalidAppAlert: Bool
    @Binding var showingClearAllManagedAppsConfirmation: Bool

    @State private var showingRemoveMultipleManagedAppsConfirmation = false
    @State private var pendingContextMenuRemovalIds: Set<String> = []
    @State private var isShowingSystemOverlayHelpPopover = false

    private var appListDescription: LocalizedStringKey {
        switch eventManager.appListMode {
        case .include:
            return "このモードでは、リスト内に追加したアプリでのみドラッグロックするようにします。"
        case .exclude:
            return "このモードでは、リスト内に追加したアプリでドラッグロックしないようにします。"
        }
    }

    private var sortedManagedAppIdentifiers: [String] {
        eventManager.managedAppBundleIdentifiers.sorted { id1, id2 in
            let name1 = applicationInfo(bundleIdentifier: id1)?.name
            let name2 = applicationInfo(bundleIdentifier: id2)?.name

            switch (name1, name2) {
            case let (.some(n1), .some(n2)):
                return n1.localizedCaseInsensitiveCompare(n2) == .orderedAscending
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return id1.localizedCaseInsensitiveCompare(id2) == .orderedAscending
            }
        }
    }

    private func applicationInfo(bundleIdentifier: String) -> ResolvedManagedApplicationInfo? {
        ManagedApplicationDisplayResolver.shared.resolvedInfo(for: bundleIdentifier)
    }

    private func addManagedApplication(bundleIdentifier: String) {
        eventManager.addManagedApp(bundleIdentifier: bundleIdentifier)
    }

    private func removeManagedApplication(bundleIdentifier: String) {
        eventManager.removeManagedApp(bundleIdentifier: bundleIdentifier)
    }

    private func requestContextMenuRemoval(for bundleIdentifier: String) {
        if selectedManagedAppIds.contains(bundleIdentifier), selectedManagedAppIds.count > 1 {
            pendingContextMenuRemovalIds = selectedManagedAppIds
        } else {
            removeManagedApplication(bundleIdentifier: bundleIdentifier)
            selectedManagedAppIds.remove(bundleIdentifier)
            pendingContextMenuRemovalIds.removeAll()
        }
    }

    private func handleDroppedAppProviders(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var invalidItemsCount = 0
        let lock = NSLock()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, _ in
                defer { group.leave() }

                guard let urlData = urlData as? Data,
                      let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                    lock.lock()
                    invalidItemsCount += 1
                    lock.unlock()
                    return
                }

                if url.pathExtension == "app" || FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                    guard let bundle = Bundle(url: url),
                          let bundleIdentifier = bundle.bundleIdentifier else {
                        lock.lock()
                        invalidItemsCount += 1
                        lock.unlock()
                        return
                    }

                    DispatchQueue.main.async {
                        addManagedApplication(bundleIdentifier: bundleIdentifier)
                    }
                } else {
                    lock.lock()
                    invalidItemsCount += 1
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            if invalidItemsCount > 0 {
                showingInvalidAppAlert = true
                #if DEBUG
                print("Dropped items include \(invalidItemsCount) non-application item(s).")
                #endif
            }
        }

        return true
    }

    private func openFinderForManagedApplication() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.prompt = NSLocalizedString("追加", comment: "Finderの実行ボタン（OKボタン）のラベル")
        openPanel.message = NSLocalizedString("ドラッグロックの対象設定に追加するアプリを選択してください。", comment: "Finderの一番上に表示されるユーザーへの指示メッセージ")
        
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            print("Failed to present open panel as sheet because no window was found")
            return
        }
        
        openPanel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = openPanel.url else { return }
            
            guard let bundle = Bundle(url: url),
                  let bundleIdentifier = bundle.bundleIdentifier else {
                showingInvalidAppAlert = true
                print("Selected item is not a valid application: \(url.path)")
                return
            }
            
            addManagedApplication(bundleIdentifier: bundleIdentifier)
        }
    }

    @ViewBuilder
    private func managedAppRow(bundleIdentifier: String) -> some View {
        if let appInfo = applicationInfo(bundleIdentifier: bundleIdentifier) {
            HStack {
                if let appIcon = appInfo.icon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                
                if bundleIdentifier.starts(with: "/") {
                    (Text(appInfo.name) + 
                     Text(" (\(bundleIdentifier))")
                        .foregroundStyle(.secondary)
                        .font(.caption))
                    .lineLimit(1)
                    .truncationMode(.middle)
                } else {
                    Text(appInfo.name)
                        .lineLimit(1)
                }
            }
            .help(bundleIdentifier.starts(with: "/") ? 
                  String(localized: "\(appInfo.name) (\(bundleIdentifier))", comment: "設定画面のアプリリストのツールチップ（パス表示）") : 
                  appInfo.name)
            .contextMenu {
                Button(role: .destructive) {
                    requestContextMenuRemoval(for: bundleIdentifier)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
            .tag(bundleIdentifier)
        } else {
            Text(bundleIdentifier)
                .foregroundStyle(.secondary)
                .help(bundleIdentifier)
                .contextMenu {
                    Button(role: .destructive) {
                        requestContextMenuRemoval(for: bundleIdentifier)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
                .tag(bundleIdentifier)
        }
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

    private var managedAppList: some View {
        List(selection: $selectedManagedAppIds) {
            ForEach(sortedManagedAppIdentifiers, id: \.self) { bundleIdentifier in
                managedAppRow(bundleIdentifier: bundleIdentifier)
            }
            .onDelete { indexSet in
                let idsToDelete = indexSet.map { sortedManagedAppIdentifiers[$0] }
                for id in idsToDelete {
                    removeManagedApplication(bundleIdentifier: id)
                }
            }
        }
        .onTapGesture {
            selectedManagedAppIds.removeAll()
        }
    }

    private var addButton: some View {
        Button {
            runningApplications = NSWorkspace.shared.runningApplications
            isShowingManagedAppPopover = true
        } label: {
            Image(systemName: "plus")
                .font(.body)
                .fontWeight(.medium)
                .frame(width: 24, height: 24)
                .offset(x: 2.0, y: -1.0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("アプリをリストへ追加します。")
        .popover(isPresented: $isShowingManagedAppPopover, arrowEdge: .leading) {
            ManagedAppPickerPopover(
                showAllRunningApps: $showAllRunningApps,
                runningApplications: runningApplications,
                existingBundleIdentifiers: Set(eventManager.managedAppBundleIdentifiers),
                onSelectRunningApplication: { bundleIdentifier in
                    addManagedApplication(bundleIdentifier: bundleIdentifier)
                    isShowingManagedAppPopover = false
                },
                onSelectFromFinder: {
                    isShowingManagedAppPopover = false
                    openFinderForManagedApplication()
                }
            )
        }
    }

    private var removeButton: some View {
        Button {
            if selectedManagedAppIds.count > 1 {
                showingRemoveMultipleManagedAppsConfirmation = true
            } else {
                let idsToRemove = selectedManagedAppIds
                for bundleIdentifier in idsToRemove {
                    removeManagedApplication(bundleIdentifier: bundleIdentifier)
                }
                selectedManagedAppIds.removeAll()
            }
        } label: {
            Image(systemName: "minus")
                .font(.body)
                .fontWeight(.medium)
                .frame(width: 24, height: 24)
                .offset(y: -0.5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(selectedManagedAppIds.isEmpty)
        .help("選択したアプリをリストから削除します。")
    }

    private var clearButton: some View {
        Button {
            showingClearAllManagedAppsConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.body)
                .fontWeight(.medium)
                .frame(width: 24, height: 24)
                .offset(x: -2.0, y: -2.0)
                .contentShape(Rectangle())
                .foregroundStyle(eventManager.managedAppBundleIdentifiers.isEmpty ? Color.secondary : Color.red)
        }
        .buttonStyle(.borderless)
        .disabled(eventManager.managedAppBundleIdentifiers.isEmpty)
        .help("すべてのアプリをリストから削除します。")
    }

    private var listToolbarOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                addButton

                Divider()
                    .frame(width: 1, height: 16)
                    .background(Color.gray.opacity(0.1))
                    .padding(.horizontal, 4)

                removeButton

                Spacer()

                clearButton
            }
            .background(Rectangle().opacity(0.04))
        }
    }

    private var managedAppListView: some View {
        managedAppList
            .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDroppedAppProviders)
            .frame(minHeight: 100)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 24)
            .accessibilityLabel(eventManager.appListMode == .exclude ? "除外するアプリリスト" : "限定するアプリリスト")
            .alert("アプリではありません", isPresented: $showingInvalidAppAlert) {
                Button("OK") { }
            } message: {
                Text("リストにはアプリのみ追加することができます。")
            }
            .overlay(alignment: .bottom) {
                listToolbarOverlay
            }
            .id(colorScheme)
    }

    var body: some View {
        Section {
            listModePicker
            managedAppListView
        } header: {
            Text("アプリの除外と限定")
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
        .alert("すべてのアプリを削除", isPresented: $showingClearAllManagedAppsConfirmation) {
            Button("削除", role: .destructive) {
                eventManager.clearManagedApps()
                selectedManagedAppIds.removeAll()
            }
            Button("キャンセル", role: .cancel) {
            }
        } message: {
            Text("リストを空にしてもよろしいですか？この操作は元に戻せません。")
        }
        .alert("複数のアプリを削除しますか？", isPresented: $showingRemoveMultipleManagedAppsConfirmation) {
            Button("削除", role: .destructive) {
                let idsToRemove = selectedManagedAppIds
                for bundleIdentifier in idsToRemove {
                    removeManagedApplication(bundleIdentifier: bundleIdentifier)
                }
                selectedManagedAppIds.removeAll()
            }
            Button("キャンセル", role: .cancel) {
            }
        } message: {
            Text("選択された\(selectedManagedAppIds.count)個のアプリをリストから削除してもよろしいですか？")
        }
        .alert(
            pendingContextMenuRemovalIds.count > 1 ? "複数のアプリを削除しますか？" : "アプリを削除しますか？",
            isPresented: Binding(
                get: { !pendingContextMenuRemovalIds.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        pendingContextMenuRemovalIds.removeAll()
                    }
                }
            )
        ) {
            Button("削除", role: .destructive) {
                let idsToRemove = pendingContextMenuRemovalIds
                for bundleIdentifier in idsToRemove {
                    removeManagedApplication(bundleIdentifier: bundleIdentifier)
                    selectedManagedAppIds.remove(bundleIdentifier)
                }
                pendingContextMenuRemovalIds.removeAll()
            }
            Button("キャンセル", role: .cancel) {
                pendingContextMenuRemovalIds.removeAll()
            }
        } message: {
            Text("選択された\(pendingContextMenuRemovalIds.count)個のアプリをリストから削除してもよろしいですか？")
        }
        .onChange(of: colorScheme) { _, _ in
            ManagedApplicationDisplayResolver.shared.clearCache()
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
        ManagedApplicationDisplayResolver.shared.resolvedInfo(for: path)?.name ?? processName
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
            return "コントロールセンターやメニューバーアイテムなど"
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
        if let bid = item.bundleIdentifier, eventManager.managedAppBundleIdentifiers.contains(bid) {
            return true
        }
        return eventManager.managedAppBundleIdentifiers.contains(item.path)
    }
    
    var body: some View {
        let appInfo = ManagedApplicationDisplayResolver.shared.resolvedInfo(for: item.path)
        
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
                    eventManager.addManagedApp(bundleIdentifier: item.bundleIdentifier ?? item.path)
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
