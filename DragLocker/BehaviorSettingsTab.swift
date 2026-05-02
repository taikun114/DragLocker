import SwiftUI
import Combine

struct BehaviorSettingsTab: View {
    @EnvironmentObject var eventManager: EventManager
    
    @State private var isShowingManagedAppPopover = false
    @State private var showAllRunningApps = false
    @State private var selectedManagedAppIds: Set<String> = []
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var showingInvalidAppAlert = false
    @State private var showingClearAllManagedAppsConfirmation = false
    
    var body: some View {
        Form {
            ManagedAppSettingsSection(
                eventManager: eventManager,
                isShowingManagedAppPopover: $isShowingManagedAppPopover,
                showAllRunningApps: $showAllRunningApps,
                selectedManagedAppIds: $selectedManagedAppIds,
                runningApplications: $runningApplications,
                showingInvalidAppAlert: $showingInvalidAppAlert,
                showingClearAllManagedAppsConfirmation: $showingClearAllManagedAppsConfirmation
            )
        }
        .formStyle(.grouped)
    }
}
