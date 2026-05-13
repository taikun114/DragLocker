import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Models & Resolvers

/// アプリ名とアイコンを保持するクラス
class ResolvedAppExclusionAndLimitationInfo {
    let name: String
    let icon: NSImage?
    
    init(name: String, icon: NSImage?) {
        self.name = name
        self.icon = icon
    }
}

/// アプリ情報を解決・キャッシュするクラス
class AppExclusionAndLimitationDisplayResolver {
    static let shared = AppExclusionAndLimitationDisplayResolver()

    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, ResolvedAppExclusionAndLimitationInfo>()
    private let lock = NSLock()
    private var searchedBundleIdentifiers: Set<String> = []
    
    func clearCache() {
        lock.lock()
        cache.removeAllObjects()
        searchedBundleIdentifiers.removeAll()
        lock.unlock()
    }

    func resolvedInfo(for identifier: String) -> ResolvedAppExclusionAndLimitationInfo? {
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

            let resolvedInfo = ResolvedAppExclusionAndLimitationInfo(
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
        
        // 2. バンドル識別子としてアプリを探す（実行中でない場合）
        if !identifier.starts(with: "/"),
           let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
           let resolvedInfo = resolvedInfo(from: applicationURL, fallbackName: identifier) {
            store(resolvedInfo, for: identifier)
            return resolvedInfo
        }

        // 3. ファイルパスとして直接アイコンを取得してみる（識別子がフルパスの場合）
        if identifier.starts(with: "/"), fileManager.fileExists(atPath: identifier) {
            let url = URL(fileURLWithPath: identifier)
            var icon = NSWorkspace.shared.icon(forFile: identifier)
            var name = url.lastPathComponent
            
            // 実行ファイルパスの場合、親ディレクトリを遡って .app を探す
            var current = url.deletingLastPathComponent()
            while current.path != "/" {
                if current.pathExtension.lowercased() == "app" {
                    icon = NSWorkspace.shared.icon(forFile: current.path)
                    // ローカライズされた名前を取得、失敗した場合は .app を除いた名前
                    name = (try? current.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                        ?? current.deletingPathExtension().lastPathComponent
                    break
                }
                current = current.deletingLastPathComponent()
            }

            let resolvedInfo = ResolvedAppExclusionAndLimitationInfo(name: name, icon: icon)
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

    private func store(_ info: ResolvedAppExclusionAndLimitationInfo, for bundleIdentifier: String) {
        cache.setObject(info, forKey: bundleIdentifier as NSString)
        lock.lock()
        searchedBundleIdentifiers.insert(bundleIdentifier)
        lock.unlock()
    }

    private func resolvedInfo(from applicationURL: URL, fallbackName: String) -> ResolvedAppExclusionAndLimitationInfo? {
        guard let appBundle = Bundle(url: applicationURL) else { return nil }

        let resolvedName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? appBundle.localizedInfoDictionary?["CFBundleName"] as? String
            ?? appBundle.infoDictionary?["CFBundleName"] as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        return ResolvedAppExclusionAndLimitationInfo(name: resolvedName, icon: icon)
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

// MARK: - UI Components

/// リストの1行分を表示するコンポーネント
struct AppExclusionAndLimitationRow: View {
    @EnvironmentObject var eventManager: EventManager
    let bundleIdentifier: String
    var showFilterMode: Bool = true
    
    private var appInfo: ResolvedAppExclusionAndLimitationInfo? {
        AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: bundleIdentifier)
    }

    private var filterMode: AppFilterMode {
        eventManager.appFilterModes[bundleIdentifier] ?? .exclude
    }

    var body: some View {
        if let appInfo = appInfo {
            HStack {
                if let appIcon = appInfo.icon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }

                if showFilterMode && eventManager.appListMode == .exclude {
                    HStack(spacing: 4) {
                        Image(systemName: filterMode.iconName)
                        Text(filterMode.localizedName)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            .tag(bundleIdentifier)
        } else {
            Text(bundleIdentifier)
                .foregroundStyle(.secondary)
                .help(bundleIdentifier)
                .tag(bundleIdentifier)
        }
    }
}

/// アプリリスト全体を管理するメインコンポーネント
struct AppExclusionAndLimitationListView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var bundleIdentifiers: [String]
    let accessibilityLabel: String
    
    init(bundleIdentifiers: Binding<[String]>, accessibilityLabel: String) {
        self._bundleIdentifiers = bundleIdentifiers
        self.accessibilityLabel = accessibilityLabel
    }

    @State private var selectedIds: Set<String> = []
    @State private var isShowingPopover = false
    @State private var showAllRunningApps = false
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var showingInvalidAppAlert = false
    @State private var showingClearConfirmation = false
    @State private var showingRemoveMultipleConfirmation = false
    @State private var idsToRemove: Set<String> = []
    
    private var sortedIdentifiers: [String] {
        bundleIdentifiers.sorted { id1, id2 in
            let name1 = AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: id1)?.name
            let name2 = AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: id2)?.name

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

    var body: some View {
        List(selection: $selectedIds) {
            ForEach(sortedIdentifiers, id: \.self) { id in
                AppExclusionAndLimitationRow(bundleIdentifier: id)
                    .contextMenu {
                        let idsForContext = selectedIds.contains(id) ? selectedIds : [id]
                        
                        if eventManager.appListMode == .exclude {
                            Picker(selection: Binding(
                                get: { eventManager.appFilterModes[id] ?? .exclude },
                                set: { newMode in
                                    for cid in idsForContext {
                                        eventManager.appFilterModes[cid] = newMode
                                    }
                                }
                            )) {
                                ForEach(AppFilterMode.allCases, id: \.self) { mode in
                                    Label(mode.localizedName, systemImage: mode.iconName)
                                        .tag(mode)
                                }
                            } label: {
                                Text("アプリモード")
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                            .labelStyle(.titleAndIcon)
                        }

                        Button(role: .destructive) {
                            requestRemove(ids: idsForContext)
                        } label: {
                            if idsForContext.count > 1 {
                                Label("削除…", systemImage: "trash")
                            } else {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
            }
            .onDelete { indexSet in
                let idsToDelete = indexSet.map { sortedIdentifiers[$0] }
                removeApps(ids: Set(idsToDelete))
            }
        }
        .onTapGesture {
            selectedIds.removeAll()
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .frame(minHeight: 120)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 24)
        .accessibilityLabel(accessibilityLabel)
        .overlay(alignment: .bottom) {
            toolbarOverlay
        }
        .alert("アプリではありません", isPresented: $showingInvalidAppAlert) {
            Button("OK") { }
        } message: {
            Text("リストにはアプリのみ追加することができます。")
        }
        .alert("すべてのアプリを削除", isPresented: $showingClearConfirmation) {
            Button("削除", role: .destructive) {
                bundleIdentifiers.removeAll()
                selectedIds.removeAll()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("リストを空にしてもよろしいですか？この操作は元に戻せません。")
        }
        .alert("複数のアプリを削除しますか？", 
               isPresented: $showingRemoveMultipleConfirmation) {
            Button("削除", role: .destructive) {
                removeApps(ids: idsToRemove)
                idsToRemove.removeAll()
            }
            Button("キャンセル", role: .cancel) {
                idsToRemove.removeAll()
            }
        } message: {
            Text("選択された\(idsToRemove.count)個のアプリをリストから削除してもよろしいですか？")
        }
        .id(colorScheme)
    }

    private func requestRemove(ids: Set<String>) {
        if ids.count > 1 {
            idsToRemove = ids
            showingRemoveMultipleConfirmation = true
        } else {
            removeApps(ids: ids)
        }
    }

    private var toolbarOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                // Add Button
                Button {
                    runningApplications = NSWorkspace.shared.runningApplications
                    isShowingPopover = true
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
                .popover(isPresented: $isShowingPopover, arrowEdge: .leading) {
                    AppExclusionAndLimitationPickerPopover(
                        showAllRunningApps: $showAllRunningApps,
                        runningApplications: runningApplications,
                        existingBundleIdentifiers: Set(bundleIdentifiers),
                        onSelectRunningApplication: { id in
                            addApp(id: id)
                            isShowingPopover = false
                        },
                        onSelectFromFinder: {
                            isShowingPopover = false
                            openFinder()
                        }
                    )
                }

                Divider()
                    .frame(width: 1, height: 16)
                    .background(Color.gray.opacity(0.1))
                    .padding(.horizontal, 4)

                // Remove Button
                Button {
                    requestRemove(ids: selectedIds)
                } label: {
                    Image(systemName: "minus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -0.6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(selectedIds.isEmpty)
                .help("選択したアプリをリストから削除します。")

                Spacer()

                if eventManager.appListMode == .exclude {
                    // Toggle Filter Mode Button
                    let nextMode: AppFilterMode = {
                        if selectedIds.isEmpty { return .ignore }
                        // 選択されているもののうち、一つでもExcludeがあればIgnoreに、そうでなければExcludeにする（トグル動作）
                        let hasExclude = selectedIds.contains { (eventManager.appFilterModes[$0] ?? .exclude) == .exclude }
                        return hasExclude ? .ignore : .exclude
                    }()

                    Button {
                        for id in selectedIds {
                            eventManager.appFilterModes[id] = nextMode
                        }
                    } label: {
                        Image(systemName: nextMode.iconName)
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(width: 24, height: 24)
                            .offset(y: -1.2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedIds.isEmpty)
                    .help(nextMode == .ignore ? "選択したアプリを「無視」に設定します。" : "選択したアプリを「除外」に設定します。")
                    
                    Divider()
                        .frame(width: 1, height: 16)
                        .background(Color.gray.opacity(0.1))
                        .padding(.horizontal, 4)
                }

                // Clear Button
                Button {
                    showingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: -2.0, y: -2.0)
                        .contentShape(Rectangle())
                        .foregroundStyle(bundleIdentifiers.isEmpty ? Color.secondary : Color.red)
                }
                .buttonStyle(.borderless)
                .disabled(bundleIdentifiers.isEmpty)
                .help("すべてのアプリをリストから削除します。")
            }
            .background(Rectangle().opacity(0.04))
        }
    }

    private func addApp(id: String) {
        if !bundleIdentifiers.contains(id) {
            bundleIdentifiers.append(id)
        }
    }

    private func removeApps(ids: Set<String>) {
        bundleIdentifiers.removeAll { ids.contains($0) }
        selectedIds.subtract(ids)
    }

    private func openFinder() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.prompt = NSLocalizedString("追加", comment: "Finderの実行ボタン（OKボタン）のラベル")
        openPanel.message = NSLocalizedString("ドラッグロックの対象設定に追加するアプリを選択してください。", comment: "Finderの一番上に表示されるユーザーへの指示メッセージ")
        
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        
        openPanel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = openPanel.url else { return }
            
            guard let bundle = Bundle(url: url),
                  let id = bundle.bundleIdentifier else {
                showingInvalidAppAlert = true
                return
            }
            
            addApp(id: id)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var invalidCount = 0
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, _ in
                defer { group.leave() }

                guard let data = urlData as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    invalidCount += 1
                    return
                }

                if url.pathExtension == "app" || FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                    guard let bundle = Bundle(url: url),
                          let id = bundle.bundleIdentifier else {
                        invalidCount += 1
                        return
                    }

                    DispatchQueue.main.async {
                        addApp(id: id)
                    }
                } else {
                    invalidCount += 1
                }
            }
        }

        group.notify(queue: .main) {
            if invalidCount > 0 {
                showingInvalidAppAlert = true
            }
        }

        return true
    }
}

// MARK: - App Picker Popover

struct AppExclusionAndLimitationPickerPopover: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showAllRunningApps: Bool

    let runningApplications: [NSRunningApplication]
    let existingBundleIdentifiers: Set<String>
    let onSelectRunningApplication: (String) -> Void
    let onSelectFromFinder: () -> Void

    @State private var currentRunningApplications: [NSRunningApplication] = []

    @State private var filteredRunningApplications: [NSRunningApplication] = []
    @State private var isLoading = false
    @State private var filterTask: Task<Void, Never>? = nil

    private func displayName(for app: NSRunningApplication) -> String {
        if let localizedName = app.localizedName, !localizedName.isEmpty {
            return localizedName
        }

        if let executableURL = app.executableURL {
            return executableURL.deletingPathExtension().lastPathComponent
        }

        return app.bundleIdentifier ?? "不明なアプリ"
    }

    private func updateFilteredApps() {
        filterTask?.cancel()
        isLoading = true

        filterTask = Task {
            let allApps = currentRunningApplications
            let showAll = showAllRunningApps
            let existingIds = existingBundleIdentifiers

            let filtered = await Task.detached(priority: .userInitiated) {
                let apps = allApps.filter { app in
                    guard !app.isTerminated else { return false }

                    let hasAppIdentity = app.bundleIdentifier != nil || app.localizedName != nil || app.executableURL != nil
                    guard hasAppIdentity else { return false }

                    let isRegularApp = app.activationPolicy == .regular

                    if !showAll {
                        return isRegularApp
                    }

                    return true
                }

                return apps
                    .filter { app in
                        if let bundleIdentifier = app.bundleIdentifier {
                            return !existingIds.contains(bundleIdentifier)
                        } else if let executablePath = app.executableURL?.path {
                            return !existingIds.contains(executablePath)
                        }
                        return true
                    }
                    .sorted { app1, app2 in
                        let name1 = app1.localizedName ?? app1.bundleIdentifier ?? ""
                        let name2 = app2.localizedName ?? app2.bundleIdentifier ?? ""
                        return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                    }
            }.value

            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.filteredRunningApplications = filtered
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshRunningApplications() {
        currentRunningApplications = NSWorkspace.shared.runningApplications
        #if DEBUG
        print("AppExclusionAndLimitationPickerPopover refreshed running applications: \(currentRunningApplications.count)")
        #endif
        updateFilteredApps()
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text("実行中のアプリから追加")
                .font(.headline)
            Spacer()
            Toggle(isOn: $showAllRunningApps) {
                Text("すべてのプロセスを表示")
            }
            .toggleStyle(.checkbox)
            .font(.subheadline)
        }
        .padding()
    }

    private var finderButton: some View {
        Button {
            onSelectFromFinder()
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                Text("Finderで選択…")
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding()
    }

    private var applicationsScrollView: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // スクロール位置の基準点
                        Color.clear
                            .frame(height: 0)
                            .id("top")

                        VStack(alignment: .leading, spacing: 16) {
                            if filteredRunningApplications.isEmpty {
                                Text("追加できる実行中のアプリが見つかりません。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(filteredRunningApplications, id: \.processIdentifier) { app in
                                    Button {
                                        if let bundleIdentifier = app.bundleIdentifier {
                                            onSelectRunningApplication(bundleIdentifier)
                                        } else if let executablePath = app.executableURL?.path {
                                            onSelectRunningApplication(executablePath)
                                        }
                                    } label: {
                                        HStack {
                                            Image(nsImage: app.icon ?? NSImage())
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                            
                                            let name = displayName(for: app)
                                            let isGenericName = name.lowercased() == "java"
                                            
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(name)
                                                    .lineLimit(2)
                                                if isGenericName, let path = app.executableURL?.path {
                                                    Text(path)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                            }
                                            
                                            Spacer()
                                            Text(String(describing: app.processIdentifier))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(app.bundleIdentifier != nil ? 
                                          String(localized: "PID: \(String(app.processIdentifier)), \(displayName(for: app))", comment: "アプリ追加リストのツールチップ（バンドルIDあり）") : 
                                          String(localized: "PID: \(String(app.processIdentifier)), \(displayName(for: app)) (\(app.executableURL?.path ?? ""))", comment: "アプリ追加リストのツールチップ（バンドルIDなし・パス表示）"))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .opacity(isLoading ? 0 : 1)
                }
                .onChange(of: showAllRunningApps) { _, _ in
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentView: some View {
        if #available(macOS 26.0, *) {
            applicationsScrollView
                .safeAreaBar(edge: .top, spacing: 0) {
                    headerBar
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    finderButton
                }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                headerBar
                applicationsScrollView
                finderButton
            }
        }
    }

    var body: some View {
        contentView
        .frame(minWidth: 280, maxWidth: 400, minHeight: 320)
        .onAppear {
            currentRunningApplications = runningApplications
            refreshRunningApplications()
        }
        .onDisappear {
            filterTask?.cancel()
            filterTask = nil
            currentRunningApplications = []
            filteredRunningApplications = []
        }
        .onChange(of: showAllRunningApps) { _, _ in
            updateFilteredApps()
        }
        .onChange(of: colorScheme) { _, _ in
            refreshRunningApplications()
        }
    }
}
// MARK: - Per-App Setting Components

/// アプリごとの設定リストを管理するコンポーネント
struct PerAppSettingListView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var perAppSettings: [String: PerAppSetting]
    
    @State private var selectedIds: Set<String> = []
    @State private var isShowingPicker = false
    @State private var showAllRunningApps = false
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var showingInvalidAppAlert = false
    @State private var showingClearConfirmation = false
    @State private var showingRemoveMultipleConfirmation = false
    @State private var idsToRemove: Set<String> = []
    @State private var editingSetting: PerAppSetting?

    private var sortedBundleIdentifiers: [String] {
        perAppSettings.keys.sorted { id1, id2 in
            let name1 = AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: id1)?.name
            let name2 = AppExclusionAndLimitationDisplayResolver.shared.resolvedInfo(for: id2)?.name
            return (name1 ?? id1).localizedCaseInsensitiveCompare(name2 ?? id2) == .orderedAscending
        }
    }

    var body: some View {
        List(selection: $selectedIds) {
            ForEach(sortedBundleIdentifiers, id: \.self) { id in
                AppExclusionAndLimitationRow(bundleIdentifier: id, showFilterMode: false)
            }
            .onDelete { indexSet in
                let idsToDelete = indexSet.map { sortedBundleIdentifiers[$0] }
                removeApps(ids: Set(idsToDelete))
            }
        }
        .contextMenu(forSelectionType: String.self) { items in
            Button {
                openSettings(for: items)
            } label: {
                Label("設定…", systemImage: "gear")
            }
            
            Divider()
            
            Button(role: .destructive) {
                requestRemove(ids: items)
            } label: {
                Label(items.count > 1 ? "削除…" : "削除", systemImage: "trash")
            }
        } primaryAction: { items in
            openSettings(for: items)
        }
        .onTapGesture {
            selectedIds.removeAll()
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .frame(minHeight: 120)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 24)
        .overlay(alignment: .bottom) {
            toolbarOverlay
        }
        .sheet(item: $editingSetting) { setting in
            PerAppSettingEditorView(setting: Binding(
                get: { self.perAppSettings[setting.bundleIdentifier] ?? setting },
                set: { self.perAppSettings[setting.bundleIdentifier] = $0 }
            ))
            .environmentObject(eventManager)
        }
        .alert("アプリではありません", isPresented: $showingInvalidAppAlert) {
            Button("OK") { }
        } message: {
            Text("リストにはアプリのみ追加することができます。")
        }
        .alert("すべてのアプリを削除", isPresented: $showingClearConfirmation) {
            Button("削除", role: .destructive) {
                perAppSettings.removeAll()
                selectedIds.removeAll()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("リストを空にしてもよろしいですか？この操作は元に戻せません。")
        }
        .alert("複数のアプリを削除しますか？", isPresented: $showingRemoveMultipleConfirmation) {
            Button("削除", role: .destructive) {
                removeApps(ids: idsToRemove)
                idsToRemove.removeAll()
            }
            Button("キャンセル", role: .cancel) {
                idsToRemove.removeAll()
            }
        } message: {
            Text("選択された\(idsToRemove.count)個のアプリをリストから削除してもよろしいですか？")
        }
    }

    private var toolbarOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button {
                    runningApplications = NSWorkspace.shared.runningApplications
                    isShowingPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: 2.0, y: -1.0)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $isShowingPicker, arrowEdge: .leading) {
                    AppExclusionAndLimitationPickerPopover(
                        showAllRunningApps: $showAllRunningApps,
                        runningApplications: runningApplications,
                        existingBundleIdentifiers: Set(perAppSettings.keys),
                        onSelectRunningApplication: { id in
                            addApp(id: id)
                            isShowingPicker = false
                        },
                        onSelectFromFinder: {
                            isShowingPicker = false
                            openFinder()
                        }
                    )
                }

                Divider()
                    .frame(width: 1, height: 16)
                    .background(Color.gray.opacity(0.1))
                    .padding(.horizontal, 4)

                Button {
                    requestRemove(ids: selectedIds)
                } label: {
                    Image(systemName: "minus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -0.6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(selectedIds.isEmpty)

                Spacer()

                Button {
                    openSettings(for: selectedIds)
                } label: {
                    Image(systemName: "gear")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -1.2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(selectedIds.isEmpty)
                .help("選択したアプリの個別設定を表示します。")

                Divider()
                    .frame(width: 1, height: 16)
                    .background(Color.gray.opacity(0.1))
                    .padding(.horizontal, 4)

                Button {
                    showingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: -2.0, y: -2.0)
                        .contentShape(Rectangle())
                        .foregroundStyle(perAppSettings.isEmpty ? Color.secondary : Color.red)
                }
                .buttonStyle(.borderless)
                .disabled(perAppSettings.isEmpty)
            }
            .background(Rectangle().opacity(0.04))
        }
    }

    private func addApp(id: String) {
        if perAppSettings[id] == nil {
            eventManager.addPerAppSetting(bundleIdentifier: id)
        }
    }

    private func openSettings(for ids: Set<String>) {
        if let first = ids.first {
            editingSetting = perAppSettings[first]
        }
    }

    private func removeApps(ids: Set<String>) {
        for id in ids {
            eventManager.removePerAppSetting(bundleIdentifier: id)
        }
        selectedIds.subtract(ids)
    }

    private func requestRemove(ids: Set<String>) {
        if ids.count > 1 {
            idsToRemove = ids
            showingRemoveMultipleConfirmation = true
        } else {
            removeApps(ids: ids)
        }
    }

    private func openFinder() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.prompt = NSLocalizedString("追加", comment: "Finderの実行ボタン（OKボタン）のラベル")
        openPanel.message = NSLocalizedString("アプリごとの動作設定に追加するアプリを選択してください。", comment: "Finderのメッセージ")
        
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        
        openPanel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = openPanel.url else { return }
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else {
                showingInvalidAppAlert = true
                return
            }
            addApp(id: id)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var invalidCount = 0
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, _ in
                defer { group.leave() }
                guard let data = urlData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    invalidCount += 1
                    return
                }
                if url.pathExtension == "app" || FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                    guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else {
                        invalidCount += 1
                        return
                    }
                    DispatchQueue.main.async {
                        addApp(id: id)
                    }
                } else {
                    invalidCount += 1
                }
            }
        }
        group.notify(queue: .main) {
            if invalidCount > 0 {
                showingInvalidAppAlert = true
            }
        }
        return true
    }
}
