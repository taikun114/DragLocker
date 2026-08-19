import Foundation
import Testing
@testable import DragLocker

@Suite("PerAppSetting Resolution Tests")
struct PerAppSettingTests {
    @Test("Resolve default setting when no app is specified")
    func testResolveDefault() {
        let eventManager = EventManager.shared
        let setting = eventManager.resolveSetting(for: nil)
        
        // グローバル設定と同じであることを確認
        #expect(setting.bundleIdentifier == "")
        #expect(setting.isIconEnabled == eventManager.isIconEnabled)
        #expect(setting.lockType == eventManager.lockType)
    }
    
    @Test("Resolve per-app setting when added")
    func testResolvePerApp() {
        let eventManager = EventManager.shared
        let testBID = "com.example.testapp"
        
        // アプリ固有の設定を追加
        eventManager.addPerAppSetting(bundleIdentifier: testBID)
        
        // 設定が追加されていることを確認
        #expect(eventManager.perAppSettings[testBID] != nil)
        
        // そのアプリの設定を解決
        let setting = eventManager.resolveSetting(for: testBID)
        #expect(setting.bundleIdentifier == testBID)
        
        // 固有設定を変更してみる
        eventManager.perAppSettings[testBID]?.overrides.insert("iconEnabled")
        eventManager.perAppSettings[testBID]?.isIconEnabled = false
        
        let updatedSetting = eventManager.resolveSetting(for: testBID)
        #expect(updatedSetting.isIconEnabled == false)
        
        // グローバル設定には影響しないことを確認
        #expect(eventManager.isIconEnabled != false || eventManager.perAppSettings[testBID]?.isIconEnabled == false)
        
        // 後片付け
        eventManager.removePerAppSetting(bundleIdentifier: testBID)
    }
}
