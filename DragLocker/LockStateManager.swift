import SwiftUI
import Combine

class LockStateManager: ObservableObject {
    static let shared = LockStateManager()
    
    @Published var isLocked: Bool = false
    @Published var lockedButtons: Set<MouseButton> = []
}
