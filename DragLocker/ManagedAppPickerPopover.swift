import AppKit
import SwiftUI

struct ManagedAppPickerPopover: View {
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
        print("ManagedAppPickerPopover refreshed running applications: \(currentRunningApplications.count)")
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
                Text("Finderで選択...")
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
                    VStack(alignment: .leading) {
                        // スクロール位置の基準点
                        Color.clear
                            .frame(height: 0)
                            .id("top")

                        if filteredRunningApplications.isEmpty {
                            Text("追加できる実行中のアプリが見つかりません。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
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
                                .padding(.vertical, 4)
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
            VStack(alignment: .leading) {
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
