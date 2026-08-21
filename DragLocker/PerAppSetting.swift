import Foundation
import SwiftUI

/// アプリケーションごとの個別のドラッグロック設定を保持する構造体
struct PerAppSetting: Codable, Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    
    // MARK: - 一般設定
    var enabledButtonRawValues: Set<Int>
    var lockType: LockType
    var lockDelay: Double
    var lockDistance: Double
    var isUnlockAllWithEscEnabled: Bool
    var isIgnoreSyntheticClicksEnabled: Bool
    
    // MARK: - アイコン設定
    var isIconEnabled: Bool
    var pointerIconStyle: IconStyle
    var iconAnimation: IconAnimation
    
    // MARK: - サウンド設定
    var isSoundEnabled: Bool
    var soundStyle: SoundStyle
    var soundVolume: Double
    var isSoundInverted: Bool
    
    // MARK: - 上書き管理
    /// 上書きが有効な項目のプロパティ名または識別子を保持する
    var overrides: Set<String>
    
    // MARK: - Initializer
    
    init(bundleIdentifier: String, eventManager: EventManager) {
        self.bundleIdentifier = bundleIdentifier
        self.overrides = []
        
        // 追加時のグローバル設定を初期値として使用
        self.enabledButtonRawValues = eventManager.enabledButtonRawValues
        self.lockType = eventManager.lockType
        self.lockDelay = eventManager.lockDelay
        self.lockDistance = eventManager.lockDistance
        self.isUnlockAllWithEscEnabled = eventManager.isUnlockAllWithEscEnabled
        self.isIgnoreSyntheticClicksEnabled = eventManager.isIgnoreSyntheticClicksEnabled
        
        self.isIconEnabled = eventManager.isIconEnabled
        self.pointerIconStyle = eventManager.pointerIconStyle
        self.iconAnimation = eventManager.iconAnimation
        
        self.isSoundEnabled = eventManager.isSoundEnabled
        self.soundStyle = eventManager.soundStyle
        self.soundVolume = eventManager.soundVolume
        self.isSoundInverted = eventManager.isSoundInverted
    }
}
