import SwiftUI
import AppKit
import Foundation
import Darwin.sys.sysctl

struct InfoView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    
    @State private var showingFeedbackMailAlert = false
    @State private var showingContributorsAlert = false
    @State private var showingBugReportAlert = false
    @State private var showingCommunityAlert = false
    @State private var showingGitHubStarAlert = false
    @State private var showingLicenseInfoModal = false
    
    var body: some View {
        Form {
            Section(header: Text("DragLockerについて").font(.headline)) {
                HStack(alignment: .center, spacing: 20) {
                    if #available(macOS 26, *) {
                        Image(nsImage: NSImage(named: NSImage.Name("AppIconLiquidGlass")) ?? NSImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 96)
                            .padding(.vertical, 10)
                            .padding(.leading, 10)
                            .id(colorScheme)
                    } else {
                        Image(nsImage: NSImage(named: NSImage.Name("AppIcon")) ?? NSImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128)
                            .padding(.vertical, 0)
                            .padding(.leading, 0)
                            .padding(.trailing, -10)
                    }
                    
                    VStack(alignment: .leading) {
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("DragLocker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
                            Text("バージョン: \(version) (\(build))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("生成AIと開発")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Copyright ©︎ 2026 今浦大雅")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                }
                
                // ライセンス情報
                HStack(alignment: .center) {
                    Text("DragLockerはオープンソースアプリケーションです。")
                    Spacer()
                    Button(action: { showingLicenseInfoModal = true }) {
                        HStack {
                            Image(systemName: "doc")
                            Text("ライセンス情報")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("このアプリケーションのライセンス情報を表示します。")
                    .sheet(isPresented: $showingLicenseInfoModal) {
                        LicenseInfoModalView()
                    }
                }
            }
            
            Section(header: Text("サポートとフィードバック").font(.headline)) {
                LabeledContent {
                    Button(action: { showingBugReportAlert = true }) {
                        Label("バグを報告", systemImage: "exclamationmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .help("既知のバグ一覧と報告ページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingBugReportAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/DragLocker/issues") {
                                openURL(url)
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("GitHubのIssueページを開いてもよろしいですか？")
                    }
                } label: {
                    Text("バグを見つけましたか？")
                }
                
                LabeledContent {
                    Button(action: { showingFeedbackMailAlert = true }) {
                        Label("フィードバックを送信", systemImage: "envelope")
                    }
                    .buttonStyle(.bordered)
                    .help("フィードバックのメール送信画面を開きます。")
                } label: {
                    Text("アイデアがありますか？")
                }
                
                LabeledContent {
                    Button(action: { showingCommunityAlert = true }) {
                        Label("コミュニティ", systemImage: "ellipsis.bubble")
                    }
                    .buttonStyle(.bordered)
                    .help("Discussionページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingCommunityAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/DragLocker/discussions") {
                                openURL(url)
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("GitHubのDiscussionページを開いてもよろしいですか？")
                    }
                } label: {
                    Text("質問や意見交換などを行いましょう")
                }
            }
            
            Section(header: Text("開発者をサポート").font(.headline)) {
                LabeledContent {
                    Button(action: { showingGitHubStarAlert = true }) {
                        Label("スターをつける", systemImage: "star")
                    }
                    .buttonStyle(.bordered)
                    .help("GitHubリポジトリページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingGitHubStarAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/DragLocker") {
                                openURL(url)
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("GitHubのリポジトリページを開いてもよろしいですか？")
                    }
                } label: {
                    Text("GitHubリポジトリにスターをつける")
                    Text("リポジトリにスターをつけてくれるととてもうれしいです！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert("メール送信画面を開きますか？", isPresented: $showingFeedbackMailAlert) {
            Button("開く") {
                if let url = URL(string: "mailto:contact.taikun@gmail.com?subject=\(formattedFeedbackSubject())&body=\(formattedFeedbackBody())") {
                    openURL(url)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("フィードバックのメール送信画面を開いてもよろしいですか？")
        }
    }
    
    private func formattedFeedbackSubject() -> String {
        let appName = "DragLocker"
        let languageCode = Locale.current.language.languageCode?.identifier
        let subjectPrefix: String = (languageCode == "ja") ? "\(appName)のフィードバック: " : "\(appName) Feedback: "
        return subjectPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
    
    private func getMachineModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func formattedFeedbackBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let appBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        
#if arch(arm64)
        let cpuArchitecture = "Apple Silicon (arm64)"
#elseif arch(x86_64)
        let cpuArchitecture = "Intel (x86_64)"
#else
        let cpuArchitecture = "N/A"
#endif
        
        let machineModelIdentifier = getMachineModelIdentifier()
        let languageCode = Locale.current.language.languageCode?.identifier
        let body: String
        
        if languageCode == "ja" {
            body = """
            フィードバック内容を具体的に説明してください:
            
            
            システム情報:
            
            ・システム
            　機種ID: \(machineModelIdentifier)
            　アーキテクチャ: \(cpuArchitecture)
            
            ・macOS
            　\(osVersion)
            
            ・アプリ
            　バージョン\(appVersion)（ビルド\(appBuildNumber)）
            """
        } else {
            body = """
            Please describe your feedback in detail:
            
            
            System Information:
            
            ・System
            　Model ID: \(machineModelIdentifier)
            　Architecture: \(cpuArchitecture)
            
            ・macOS
            　\(osVersion)
            
            ・App
            　Version \(appVersion) (Build \(appBuildNumber))
            """
        }
        
        return body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
}

#Preview {
    InfoView()
        .frame(width: 450, height: 450)
}
