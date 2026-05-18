import Foundation
import StoreKit
import SwiftUI
import Combine

public class ReviewRequestManager: ObservableObject {
    public static let shared = ReviewRequestManager()
    
    private let userDefaults = UserDefaults.standard
    
    // ユーザーデフォルト用のキー
    private let kDragLockStartCount = "review_dragLockStartCount"
    private let kLastRequestDate = "review_lastRequestDate"
    private let kLastRequestVersion = "review_lastRequestVersion"
    private let kLastUpdateDate = "review_lastUpdateDate"
    private let kCurrentVersion = "review_currentVersion"
    private let kTodayCount = "review_todayCount"
    private let kLastCountDate = "review_lastCountDate"
    
    @Published public var shouldPresentReview = false
    private var reviewRequestTimer: Timer?
    
    private init() {
        checkVersionAndInitialize()
    }
    
    public var dragLockStartCount: Int {
        get { userDefaults.integer(forKey: kDragLockStartCount) }
        set { 
            userDefaults.set(newValue, forKey: kDragLockStartCount)
            objectWillChange.send()
        }
    }
    
    public var lastRequestDate: Date? {
        get { userDefaults.object(forKey: kLastRequestDate) as? Date }
        set { 
            userDefaults.set(newValue, forKey: kLastRequestDate)
            objectWillChange.send()
        }
    }
    
    public var lastRequestVersion: String? {
        get { userDefaults.string(forKey: kLastRequestVersion) }
        set { 
            userDefaults.set(newValue, forKey: kLastRequestVersion)
            objectWillChange.send()
        }
    }
    
    public var lastUpdateDate: Date {
        get { (userDefaults.object(forKey: kLastUpdateDate) as? Date) ?? Date() }
        set { 
            userDefaults.set(newValue, forKey: kLastUpdateDate)
            objectWillChange.send()
        }
    }
    
    public var currentVersion: String {
        get { userDefaults.string(forKey: kCurrentVersion) ?? "" }
        set { 
            userDefaults.set(newValue, forKey: kCurrentVersion)
            objectWillChange.send()
        }
    }
    
    public var todayCount: Int {
        get { userDefaults.integer(forKey: kTodayCount) }
        set { 
            userDefaults.set(newValue, forKey: kTodayCount)
            objectWillChange.send()
        }
    }
    
    private var lastCountDate: String? {
        get { userDefaults.string(forKey: kLastCountDate) }
        set { userDefaults.set(newValue, forKey: kLastCountDate) }
    }
    
    // アプリの現在のバージョンを取得
    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func checkVersionAndInitialize() {
        let actualVersion = appVersion
        let savedVersion = currentVersion
        
        if savedVersion.isEmpty {
            // 初回インストール
            currentVersion = actualVersion
            lastUpdateDate = Date()
            dragLockStartCount = 0
        } else if savedVersion != actualVersion {
            // アプリがアップデートされた
            currentVersion = actualVersion
            lastUpdateDate = Date()
            dragLockStartCount = 0
        }
    }
    
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public func incrementCountIfNeeded() {
        // 1. 同一バージョンで既にレビュー要求済みか確認
        if let lastReqVer = lastRequestVersion, lastReqVer == appVersion {
            #if DEBUG
            print("ReviewRequestManager: Already requested review for version \(appVersion)")
            #endif
            return
        }
        
        // 2. 前回のレビュー要求から90日経過しているか確認
        if let lastRequest = lastRequestDate {
            let secondsSinceLastRequest = Date().timeIntervalSince(lastRequest)
            let daysSinceLastRequest = secondsSinceLastRequest / (24 * 60 * 60)
            if daysSinceLastRequest < 90 {
                #if DEBUG
                print("ReviewRequestManager: Cooldown active. Days remaining: \(90 - daysSinceLastRequest)")
                #endif
                return
            }
        }
        
        // 3. 1日の加算制限（最大34回）
        let todayStr = getTodayString()
        if lastCountDate != todayStr {
            lastCountDate = todayStr
            todayCount = 0
        }
        
        if todayCount >= 34 {
            #if DEBUG
            print("ReviewRequestManager: Daily limit reached (34)")
            #endif
            return
        }
        
        // 4. カウントを加算
        todayCount += 1
        dragLockStartCount += 1
        
        #if DEBUG
        print("ReviewRequestManager: Count incremented to \(dragLockStartCount). Today's count: \(todayCount)")
        #endif
    }
    
    public func scheduleReviewRequest() {
        cancelScheduledReviewRequest()
        
        // カウントが100回未満の場合は何もしない
        guard dragLockStartCount >= 100 else { return }
        
        // 同一バージョンで既に要求済みか確認
        if let lastReqVer = lastRequestVersion, lastReqVer == appVersion { return }
        
        // 前回の要求から90日経過しているか確認
        if let lastRequest = lastRequestDate {
            let days = Date().timeIntervalSince(lastRequest) / (24 * 60 * 60)
            if days < 90 { return }
        }
        
        // 初回起動またはアップデート後、最低3日間（72時間）経過しているか確認
        let hoursSinceUpdate = Date().timeIntervalSince(lastUpdateDate) / 3600
        if hoursSinceUpdate < 72 {
            #if DEBUG
            print("ReviewRequestManager: Initial 3 days wait not completed yet (\(hoursSinceUpdate) hours elapsed)")
            #endif
            return
        }
        
        #if DEBUG
        print("ReviewRequestManager: Conditions met. Scheduling review in 1 second...")
        #endif
        
        // 1秒後に実行するタイマーをセット
        DispatchQueue.main.async { [weak self] in
            self?.reviewRequestTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                // 現在ロックされていないことを最終確認
                if !EventManager.shared.isLocked {
                    #if DEBUG
                    print("ReviewRequestManager: Timer fired and not locked. Setting shouldPresentReview to true.")
                    #endif
                    self.shouldPresentReview = true
                } else {
                    #if DEBUG
                    print("ReviewRequestManager: Timer fired but locked. Will retry on next release.")
                    #endif
                }
            }
        }
    }
    
    public func cancelScheduledReviewRequest() {
        reviewRequestTimer?.invalidate()
        reviewRequestTimer = nil
    }
    
    public func markReviewAsRequested() {
        lastRequestDate = Date()
        lastRequestVersion = appVersion
        dragLockStartCount = 0 // レビュー表示後にカウントをリセット
        shouldPresentReview = false
        #if DEBUG
        print("ReviewRequestManager: Review request recorded for version \(appVersion)")
        #endif
    }
    
    // MARK: - Debug Methods
    #if DEBUG
    public func debugSetCountTo99() {
        dragLockStartCount = 99
    }
    
    public func debugResetCount() {
        dragLockStartCount = 0
        todayCount = 0
    }
    
    public func debugResetLastRequestDate() {
        lastRequestDate = nil
        lastRequestVersion = nil
    }
    
    public func debugResetUpdateDate() {
        lastUpdateDate = Date()
    }
    
    public func debugSetUpdateDateTo3DaysAgo() {
        lastUpdateDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
    }
    
    public func debugForceShowRequest() {
        shouldPresentReview = true
    }
    #endif
}
