//
//  DragLockerTests.swift
//  DragLockerTests
//
//  Created by 今浦大雅 on 2026/03/16.
//

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

    @Test func testManagedApplicationListEvaluatorExcludeMode() {
        let listedBundleIdentifiers: Set<String> = ["com.apple.finder", "com.apple.Safari"]

        #expect(
            ManagedApplicationListEvaluator.shouldLock(
                bundleIdentifier: "com.apple.finder",
                mode: .exclude,
                listedBundleIdentifiers: listedBundleIdentifiers
            ) == false
        )
        #expect(
            ManagedApplicationListEvaluator.shouldLock(
                bundleIdentifier: "com.apple.TextEdit",
                mode: .exclude,
                listedBundleIdentifiers: listedBundleIdentifiers
            ) == true
        )
        #expect(
            ManagedApplicationListEvaluator.shouldLock(
                bundleIdentifier: nil,
                mode: .exclude,
                listedBundleIdentifiers: listedBundleIdentifiers
            ) == true
        )
    }

    @Test func testManagedApplicationListEvaluatorIncludeMode() {
        let listedBundleIdentifiers: Set<String> = ["com.apple.finder", "com.apple.Safari"]

        #expect(
            ManagedApplicationListEvaluator.shouldLock(
                bundleIdentifier: "com.apple.Safari",
                mode: .include,
                listedBundleIdentifiers: listedBundleIdentifiers
            ) == true
        )
        #expect(
            ManagedApplicationListEvaluator.shouldLock(
                bundleIdentifier: "com.apple.TextEdit",
                mode: .include,
                listedBundleIdentifiers: listedBundleIdentifiers
            ) == false
        )
        #expect(
            ManagedApplicationListEvaluator.shouldLock(
                bundleIdentifier: nil,
                mode: .include,
                listedBundleIdentifiers: listedBundleIdentifiers
            ) == false
        )
    }

}
