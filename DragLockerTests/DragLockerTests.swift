//
//  DragLockerTests.swift
//  DragLockerTests
//
//  Created by 今浦大雅 on 2026/03/16.
//

import Foundation
import Testing
@testable import DragLocker

struct DragLockerTests {

    @Test func testSoundManagerGetFileName() {
        let soundManager = SoundManager.shared
        
        // 各スタイルと期待されるベースファイル名の定義
        let expectedFiles: [(SoundStyle, String)] = [
            (.system, ""),
            (.snap, "snap"),
            (.click, "click"),
            (.clickLow, "click_low"),
            (.click2, "click_2"),
            (.ping, "ping"),
            (.pingLow, "ping_low"),
            (.ping2, "ping_2"),
            (.ping2Low, "ping_2_low"),
            (.soft, "soft"),
            (.silkey, "silkey"),
            (.marimba, "marimba"),
            (.marimbaLow, "marimba_low"),
            (.miniMarimba, "mini_marimba"),
            (.eightBit, "8bit"),
            (.eightBitLow, "8bit_low"),
            (.drum, "drum")
        ]
        
        for (style, expectedName) in expectedFiles {
            let actualName = soundManager.getFileName(for: style)
            #expect(actualName == expectedName, "Style \(style.rawValue) should return file name '\(expectedName)', but got '\(actualName)'")
        }
    }

    @Test func testAppExclusionAndLimitationEvaluatorExcludeMode() {
        let listedIdentifiers: Set<String> = ["com.apple.finder", "com.apple.Safari"]

        #expect(
            AppExclusionAndLimitationEvaluator.shouldLock(
                bundleIdentifier: "com.apple.finder",
                executableName: "Finder",
                executablePath: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder",
                mode: .exclude,
                listedIdentifiers: listedIdentifiers
            ) == false
        )
        #expect(
            AppExclusionAndLimitationEvaluator.shouldLock(
                bundleIdentifier: "com.apple.TextEdit",
                executableName: "TextEdit",
                executablePath: "/System/Applications/TextEdit.app/Contents/MacOS/TextEdit",
                mode: .exclude,
                listedIdentifiers: listedIdentifiers
            ) == true
        )
        #expect(
            AppExclusionAndLimitationEvaluator.shouldLock(
                bundleIdentifier: nil,
                executableName: nil,
                executablePath: nil,
                mode: .exclude,
                listedIdentifiers: listedIdentifiers
            ) == true
        )
    }

    @Test func testAppExclusionAndLimitationEvaluatorIncludeMode() {
        let listedIdentifiers: Set<String> = ["com.apple.finder", "com.apple.Safari"]

        #expect(
            AppExclusionAndLimitationEvaluator.shouldLock(
                bundleIdentifier: "com.apple.Safari",
                executableName: "Safari",
                executablePath: "/Applications/Safari.app/Contents/MacOS/Safari",
                mode: .include,
                listedIdentifiers: listedIdentifiers
            ) == true
        )
        #expect(
            AppExclusionAndLimitationEvaluator.shouldLock(
                bundleIdentifier: "com.apple.TextEdit",
                executableName: "TextEdit",
                executablePath: "/System/Applications/TextEdit.app/Contents/MacOS/TextEdit",
                mode: .include,
                listedIdentifiers: listedIdentifiers
            ) == false
        )
        #expect(
            AppExclusionAndLimitationEvaluator.shouldLock(
                bundleIdentifier: nil,
                executableName: nil,
                executablePath: nil,
                mode: .include,
                listedIdentifiers: listedIdentifiers
            ) == false
        )
    }

    @Test func testReviewRequestManagerLogic() {
        let manager = ReviewRequestManager.shared
        
        // デバッグメソッドを使用して初期状態にリセット
        manager.debugResetCount()
        manager.debugResetLastRequestDate()
        manager.debugResetUpdateDate()
        
        // 初期のカウント確認
        #expect(manager.dragLockStartCount == 0)
        
        // カウントのインクリメント
        manager.incrementCountIfNeeded()
        #expect(manager.dragLockStartCount == 1)
        
        // 99にセット
        manager.debugSetCountTo99()
        #expect(manager.dragLockStartCount == 99)
        
        // さらにインクリメントして100にする
        manager.incrementCountIfNeeded()
        #expect(manager.dragLockStartCount == 100)
        
        // アップデート日を3日前に変更する
        manager.debugSetUpdateDateTo3DaysAgo()
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: manager.lastUpdateDate, to: Date()).day ?? 0
        #expect(days >= 3)
        
        // レビュー要求済みマークをしてカウントが0にリセットされることを確認
        manager.markReviewAsRequested()
        #expect(manager.dragLockStartCount == 0)
    }

}
