import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage: Int
    @State private var slideForward = true
    @State private var hasRequestedAccessibility = false
    @State private var hasRequestedNotification = false
    @State private var permissionCheckTimer: Timer?

    var onComplete: () -> Void

    init(startPage: Int = 0, onComplete: @escaping () -> Void) {
        _currentPage = State(initialValue: startPage)
        self.onComplete = onComplete
    }
    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea() // 背景だけをウィンドウ全体に広げる

            mainContent // コンテンツはシステムのセーフエリアに従う
        }
        .frame(width: 300, height: 400)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            } else {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
            }

        if colorScheme == .light {
            if #available(macOS 26.0, *) {
                Color(red: 110.0 / 255.0, green: 185.0 / 255.0, blue: 245.0 / 255.0)
                    .opacity(0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                Color(red: 110.0 / 255.0, green: 185.0 / 255.0, blue: 245.0 / 255.0)
                    .opacity(0.5)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
            }
        }
        }
    }

    // MARK: - メインコンテンツ

    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                pageContent(for: currentPage)
                    .id(currentPage)
                    .transition(.asymmetric(
                        insertion: .move(edge: slideForward ? .trailing : .leading),
                        removal: .move(edge: slideForward ? .leading : .trailing)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            navigationButtons
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage == 1 {
                startPermissionPolling()
            } else {
                stopPermissionPolling()
            }
        }
        .onDisappear {
            stopPermissionPolling()
        }
    }

    // MARK: - ページコンテンツ

    @ViewBuilder
    private func pageContent(for page: Int) -> some View {
        switch page {
        case 0:
            welcomePage
        case 1:
            permissionsPage
        case 2:
            buttonsPage
        case 3:
            methodPage
        case 4:
            completionPage
        default:
            EmptyView()
        }
    }

    // MARK: - ナビゲーションボタン

    private var navigationButtons: some View {
        HStack {
            if currentPage > 0 {
                Button("戻る") {
                    goToPreviousPage()
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .help("前のページに戻ります。")
            }

            Spacer()

            if currentPage < 4 {
                Button("次へ") {
                    goToNextPage()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(
                    (currentPage == 1 && !eventManager.isTrusted) ||
                    (currentPage == 2 && eventManager.enabledButtonRawValues.isEmpty)
                )
                .help(
                    currentPage == 1 && !eventManager.isTrusted ? "続行するにはアクセシビリティ権限を許可する必要があります。" :
                    (currentPage == 2 && eventManager.enabledButtonRawValues.isEmpty ? "少なくとも1つのボタンを選択する必要があります" : "次のページに進みます。")
                )
            } else {
                Button("完了") {
                    stopPermissionPolling()
                    hasCompletedOnboarding = true
                    print("DEBUG: @AppStorage hasCompletedOnboarding = \(hasCompletedOnboarding)")
                    print("DEBUG: UserDefaults = \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                    onComplete()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .help("初期設定を完了します。")
            }
        }
        .padding()
    }

    private func goToNextPage() {
        slideForward = true
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }

    private func goToPreviousPage() {
        slideForward = false
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage -= 1
        }
    }

    // MARK: - ページ1: ようこそ

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("DragLocker_Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            Image("DragLocker_Logo_Text")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160)

            Spacer()

            VStack(spacing: 4) {
                Text("DragLockerへようこそ")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("あらゆるマウスでドラッグロック可能にします。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - ページ2: 権限

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 4) {
                Text("権限")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("一部の機能には許可を与える必要があります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            permissionRow(
                icon: "accessibility",
                title: "アクセシビリティ",
                description: "ドラッグロックはマウスイベントを書き換える必要があるため、ドラッグロックを使用するためには許可が必要です（必須）。",
                isGranted: eventManager.isTrusted,
                hasRequested: hasRequestedAccessibility,
                onRequest: {
                    eventManager.requestAccessibilityPermissions()
                    hasRequestedAccessibility = true
                },
                onOpenSettings: {
                    eventManager.openAccessibilitySettings()
                }
            )

            permissionRow(
                icon: "bell.badge",
                title: "通知",
                description: "ドラッグロック監視が切り替わった時などに通知を受け取りたい場合は許可が必要です（オプション）。",
                isGranted: eventManager.isNotificationTrusted,
                hasRequested: hasRequestedNotification,
                onRequest: {
                    eventManager.requestNotificationPermissions()
                    hasRequestedNotification = true
                },
                onOpenSettings: {
                    eventManager.openNotificationSettings()
                }
            )

            Spacer()
        }
        .padding(.horizontal)
    }

    private func permissionRow(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        isGranted: Bool,
        hasRequested: Bool,
        onRequest: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.accent)
                    .frame(width: 32, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Group {
                if isGranted {
                    Button {} label: {
                        Label("許可済み", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .help("この権限は正しく許可されています。")
                } else if hasRequested {
                    Button {
                        onOpenSettings()
                    } label: {
                        Label("設定を開く", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .help("システム設定を開いて権限を付与します。")
                } else {
                    Button {
                        onRequest()
                    } label: {
                        Label("許可", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .help("この権限の許可を要求します。")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func startPermissionPolling() {
        stopPermissionPolling()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            eventManager.checkAccessibilityPermissions()
            eventManager.checkNotificationPermissions()
        }
    }

    private func stopPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    // MARK: - ページ3: ロック対象ボタン

    private var buttonsPage: some View {
        VStack {
            VStack(spacing: 4) {
                Text("ロック対象ボタン")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("ドラッグロックを使用するマウスボタンを選択します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                mouseButtonSelection(imageName: "DragLocker_Button_Left", title: "左", button: .left)
                Spacer(minLength: 0)
                mouseButtonSelection(imageName: "DragLocker_Button_Wheel", title: "ホイール", button: .middle)
                Spacer(minLength: 0)
                mouseButtonSelection(imageName: "DragLocker_Button_Right", title: "右", button: .right)
            }
            .padding(.vertical)

            Spacer(minLength: 0)

            Text("これらは後で設定からカスタマイズできます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - ページ4: ロック方法

    private var methodPage: some View {
        VStack {
            VStack(spacing: 4) {
                Text("ロック方法")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("ドラッグロックを開始する方法を選択します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                methodButton(imageName: "DragLocker_Method_Time", title: "時間", type: .time)
                Spacer(minLength: 0)
                methodButton(imageName: "DragLocker_Method_Distance", title: "距離", type: .distance)
                Spacer(minLength: 0)
                methodButton(imageName: "DragLocker_Method_Both", title: "両方", type: .both)
            }
            .padding(.vertical)

            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    HStack {
                        Text("ロックまでの時間")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.lockType == .distance ? .secondary : .primary)
                        Spacer()
                        Text("\(eventManager.lockDelay, format: .number.precision(.fractionLength(1))) 秒")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.lockType == .distance ? .tertiary : .secondary)
                    }
                    Slider(value: $eventManager.lockDelay, in: 0.2...3.0, step: 0.1) {
                        Text("ロックまでの時間")
                    }
                    .labelsHidden()
                        .help("マウスボタンを押し続けてからロックされるまでの時間。")
                }
                .disabled(eventManager.lockType == .distance)

                VStack(spacing: 4) {
                    HStack {
                        Text("ロックまでの距離")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.lockType == .time ? .secondary : .primary)
                        Spacer()
                        Text("\(eventManager.lockDistance, format: .number.precision(.fractionLength(0))) px")
                            .font(.subheadline)
                            .foregroundStyle(eventManager.lockType == .time ? .tertiary : .secondary)
                    }
                    Slider(value: $eventManager.lockDistance, in: 10...500, step: 10) {
                        Text("ロックまでの距離")
                    }
                    .labelsHidden()
                        .help("マウスボタンを押してからロックされるまでの移動距離。")
                }
                .disabled(eventManager.lockType == .time)
            }

            Spacer(minLength: 0)

            Text("これらは後で設定からカスタマイズできます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func methodButton(imageName: String, title: String, type: LockType) -> some View {
        let isSelected = eventManager.lockType == type
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                eventManager.lockType = type
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit) // 画像の比率を完全に維持
                        .frame(height: 110) // さらに大きく
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.system(size: 16))
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 6, y: 6)
                    }
                }
                // チェックマークのオフセット(6)の重みを、左右対称なネガティブパディングで打ち消す
                // これにより、画像の中心が完璧にボタンの中心（ひいてはスライダーの中心）と一致する
                .padding(.horizontal, -3)
                .padding(.bottom, -3)
                
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .help(Text("「\(String(localized: LocalizedStringResource(stringLiteral: title)))」方式でドラッグロックを開始します。"))
    }

    private func mouseButtonSelection(imageName: String, title: String, button: MouseButton) -> some View {
        let isSelected = eventManager.enabledButtonRawValues.contains(button.rawValue)
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    eventManager.enabledButtonRawValues.remove(button.rawValue)
                } else {
                    eventManager.enabledButtonRawValues.insert(button.rawValue)
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.system(size: 16))
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 6, y: 6)
                    }
                }
                .padding(.horizontal, -3)
                .padding(.bottom, -3)
                
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .help(Text("\(String(localized: LocalizedStringResource(stringLiteral: title)))ボタンをドラッグロックの対象にします。"))
    }

    // MARK: - ページ5: 初期設定完了

    private var completionPage: some View {
        VStack(spacing: 16) {

            Spacer()

            if #available(macOS 26.0, *) {
                Image("DragLocker_MenuBar")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 256)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            } else {
                Image("DragLocker_MenuBar_Old")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 256)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }

            Spacer()

            VStack(spacing: 4) {
                Text("初期設定完了")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Text("最低限の初期設定が完了しました。\nドラッグロックの動作をカスタマイズするにはメニューバーアイコンから設定を開きます。\n\nDragLockerをお楽しみください！")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
    }
}

#Preview("Page 1: Welcome") {
    OnboardingView(startPage: 0, onComplete: {})
        .environmentObject(EventManager.shared)
        .frame(width: 300, height: 400)
}

#Preview("Page 2: Permissions") {
    OnboardingView(startPage: 1, onComplete: {})
        .environmentObject(EventManager.shared)
        .frame(width: 300, height: 400)
}

#Preview("Page 3: Buttons") {
    OnboardingView(startPage: 2, onComplete: {})
        .environmentObject(EventManager.shared)
        .frame(width: 300, height: 400)
}

#Preview("Page 4: Methods") {
    OnboardingView(startPage: 3, onComplete: {})
        .environmentObject(EventManager.shared)
        .frame(width: 300, height: 400)
}

#Preview("Page 5: Completion") {
    OnboardingView(startPage: 4, onComplete: {})
        .environmentObject(EventManager.shared)
        .frame(width: 300, height: 400)
}
