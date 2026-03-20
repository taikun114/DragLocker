import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ManagedAppSettingsSection: View {
    @ObservedObject var eventManager: EventManager

    @Binding var isShowingManagedAppPopover: Bool
    @Binding var showAllRunningApps: Bool
    @Binding var selectedManagedAppIds: Set<String>
    @Binding var runningApplications: [NSRunningApplication]
    @Binding var showingInvalidAppAlert: Bool
    @Binding var showingClearAllManagedAppsConfirmation: Bool

    @State private var showingRemoveMultipleManagedAppsConfirmation = false
    @State private var pendingContextMenuRemovalIds: Set<String> = []

    private var appListDescription: String {
        switch eventManager.appListMode {
        case .include:
            return "このモードでは、リスト内に追加したアプリでのみドラッグロックするようにします。"
        case .exclude:
            return "このモードでは、リスト内に追加したアプリでドラッグロックしないようにします。"
        }
    }

    private var sortedManagedAppIdentifiers: [String] {
        eventManager.managedAppBundleIdentifiers.sorted { id1, id2 in
            let name1 = applicationName(bundleIdentifier: id1)
            let name2 = applicationName(bundleIdentifier: id2)

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

    private func applicationURL(bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    private func applicationName(bundleIdentifier: String) -> String? {
        guard let appURL = applicationURL(bundleIdentifier: bundleIdentifier),
              let appBundle = Bundle(url: appURL) else {
            return nil
        }

        return appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? appBundle.localizedInfoDictionary?["CFBundleName"] as? String
            ?? appBundle.infoDictionary?["CFBundleName"] as? String
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
                print("Dropped items include \(invalidItemsCount) non-application item(s).")
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
        openPanel.prompt = "追加"
        openPanel.message = "ドラッグロックの対象設定に追加するアプリを選択してください。"
        
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
        if let appURL = applicationURL(bundleIdentifier: bundleIdentifier),
           let appName = applicationName(bundleIdentifier: bundleIdentifier) {
            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)

            HStack {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(appName)
            }
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
                Text(mode.rawValue).tag(mode)
            }
        } label: {
            Text("リストモード")
            Text(appListDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
            .accessibilityLabel("特定のアプリでの動作リスト")
            .alert("アプリではありません", isPresented: $showingInvalidAppAlert) {
                Button("OK") { }
            } message: {
                Text("リストにはアプリのみ追加することができます。")
            }
            .overlay(alignment: .bottom) {
                listToolbarOverlay
            }
    }

    var body: some View {
        Section {
            listModePicker
            managedAppListView
        } header: {
            Text("特定のアプリでの動作")
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
    }
}
