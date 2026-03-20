import AppKit
import SwiftUI

struct ManagedAppPickerPopover: View {
    @Binding var showAllRunningApps: Bool

    let runningApplications: [NSRunningApplication]
    let existingBundleIdentifiers: Set<String>
    let onSelectRunningApplication: (String) -> Void
    let onSelectFromFinder: () -> Void

    @State private var currentRunningApplications: [NSRunningApplication] = []

    private var filteredRunningApplications: [NSRunningApplication] {
        let filteredApps = currentRunningApplications.filter { app in
            guard !app.isTerminated else { return false }

            let hasAppIdentity = app.bundleIdentifier != nil || app.localizedName != nil || app.executableURL != nil
            guard hasAppIdentity else { return false }

            let isRegularApp = app.activationPolicy == .regular

            if !showAllRunningApps {
                return isRegularApp
            }

            return true
        }

        return filteredApps
            .filter { app in
                guard let bundleIdentifier = app.bundleIdentifier else { return true }
                return !existingBundleIdentifiers.contains(bundleIdentifier)
            }
            .sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
            }
    }

    private func displayName(for app: NSRunningApplication) -> String {
        if let localizedName = app.localizedName, !localizedName.isEmpty {
            return localizedName
        }

        if let executableURL = app.executableURL {
            return executableURL.deletingPathExtension().lastPathComponent
        }

        return app.bundleIdentifier ?? "不明なアプリ"
    }

    private func refreshRunningApplications() {
        currentRunningApplications = NSWorkspace.shared.runningApplications
        print("ManagedAppPickerPopover refreshed running applications: \(currentRunningApplications.count)")
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
        ScrollView {
            VStack(alignment: .leading) {
                if filteredRunningApplications.isEmpty {
                    Text("追加できる実行中のアプリが見つかりません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }

                ForEach(filteredRunningApplications, id: \.processIdentifier) { app in
                    Button {
                        guard let bundleIdentifier = app.bundleIdentifier else { return }
                        onSelectRunningApplication(bundleIdentifier)
                    } label: {
                        HStack {
                            Image(nsImage: app.icon ?? NSImage())
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(displayName(for: app))
                            Spacer()
                            Text(String(describing: app.processIdentifier))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("PID: \(String(describing: app.processIdentifier))")
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }
}
