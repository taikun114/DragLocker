import AppKit
import AVFoundation
import Foundation
import SwiftUI

enum SoundStyle: String, CaseIterable, Sendable {
    case system = "システム"
    case snap = "スナップ"
    case click = "クリック"
    case clickLow = "クリック（低）"
    case click2 = "クリック 2"
    case ping = "ピッ"
    case pingLow = "ピッ（低）"
    case ping2 = "ピッ 2"
    case ping2Low = "ピッ 2（低）"
    case soft = "ソフト"
    case silkey = "シルキー"
    case marimba = "マリンバ"
    case marimbaLow = "マリンバ（低）"
    case miniMarimba = "ミニマリンバ"
    case eightBit = "8ビット"
    case eightBitLow = "8ビット（低）"
    case drum = "ドラム"

    var localizedName: LocalizedStringResource {
        switch self {
        case .system: return LocalizedStringResource("システム", comment: "サウンドの種類：OS標準のビープ音")
        case .snap: return LocalizedStringResource("スナップ", comment: "サウンドの種類：スナップ音")
        case .click: return LocalizedStringResource("クリック", comment: "サウンドの種類：標準的なクリック音")
        case .clickLow: return LocalizedStringResource("クリック（低）", comment: "サウンドの種類：低いトーンのクリック音")
        case .click2: return LocalizedStringResource("クリック 2", comment: "サウンドの種類：別のクリック音バリエーション")
        case .ping: return LocalizedStringResource("ピッ", comment: "サウンドの種類：電子的なピッという音")
        case .pingLow: return LocalizedStringResource("ピッ（低）", comment: "サウンドの種類：低い電子ピッ音")
        case .ping2: return LocalizedStringResource("ピッ 2", comment: "サウンドの種類：電子音のバリエーション")
        case .ping2Low: return LocalizedStringResource("ピッ 2（低）", comment: "サウンドの種類：低い電子音バリエーション")
        case .soft: return LocalizedStringResource("ソフト", comment: "サウンドの種類：柔らかい音")
        case .silkey: return LocalizedStringResource("シルキー", comment: "サウンドの種類：滑らかな音")
        case .marimba: return LocalizedStringResource("マリンバ", comment: "サウンドの種類：マリンバの音")
        case .marimbaLow: return LocalizedStringResource("マリンバ（低）", comment: "サウンドの種類：低いマリンバの音")
        case .miniMarimba: return LocalizedStringResource("ミニマリンバ", comment: "サウンドの種類：小さなマリンバの音")
        case .eightBit: return LocalizedStringResource("8ビット", comment: "サウンドの種類：レトロなゲーム風の音")
        case .eightBitLow: return LocalizedStringResource("8ビット（低）", comment: "サウンドの種類：低いトーンの8ビット音")
        case .drum: return LocalizedStringResource("ドラム", comment: "サウンドの種類：太鼓のような音")
        }
    }
}

class SoundManager {
    static let shared = SoundManager()
    
    // スタイルと方向（up/down）の組み合わせをキーにしてプレイヤーをキャッシュ
    private var players: [String: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "com.draglocker.soundmanager", qos: .utility)
    
    private init() {}
    
    // 指定されたスタイルをロードする（すでにロード済みの場合は何もしない）
    func loadSound(style: SoundStyle) {
        if style == .system { return }
        
        queue.async {
            for suffix in ["_up", "_down"] {
                let key = "\(style.rawValue)\(suffix)"
                if self.players[key] == nil {
                    let baseName = self.getFileName(for: style)
                    let fileName = baseName + suffix
                    if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
                        do {
                            let player = try AVAudioPlayer(contentsOf: url)
                            player.prepareToPlay()
                            self.players[key] = player
                        } catch {
                            print("Failed to load sound: \(fileName), error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // 指定されたスタイル以外をメモリから解放する
    func cleanupExcept(activeStyle: SoundStyle) {
        queue.async {
            let activeUpKey = "\(activeStyle.rawValue)_up"
            let activeDownKey = "\(activeStyle.rawValue)_down"
            
            let keysToRemove = self.players.keys.filter { $0 != activeUpKey && $0 != activeDownKey }
            for key in keysToRemove {
                self.players.removeValue(forKey: key)
            }
            print("Sound memory cleaned up. Remaining players: \(self.players.keys.count)")
        }
    }
    
    func play(style: SoundStyle, volume: Double, isLocked: Bool, isInverted: Bool = false) {
        if style == .system {
            queue.async {
                NSSound.beep()
            }
            return
        }
        
        let effectiveIsLocked = isInverted ? !isLocked : isLocked
        let suffix = effectiveIsLocked ? "_up" : "_down"
        playSpecific(style: style, volume: volume, suffix: suffix)
    }
    
    func preview(style: SoundStyle, volume: Double, isInverted: Bool = false) {
        if style == .system {
            queue.async {
                NSSound.beep()
            }
            return
        }
        
        // ロック音を再生
        let firstSuffix = isInverted ? "_down" : "_up"
        playSpecific(style: style, volume: volume, suffix: firstSuffix)
        
        // 0.4秒後に解除音を再生
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let secondSuffix = isInverted ? "_up" : "_down"
            self.playSpecific(style: style, volume: volume, suffix: secondSuffix)
        }
    }
    
    private func playSpecific(style: SoundStyle, volume: Double, suffix: String) {
        let key = "\(style.rawValue)\(suffix)"
        if let player = players[key] {
            queue.async {
                player.volume = Float(volume)
                player.currentTime = 0
                player.play()
            }
        } else {
            loadAndPlay(style: style, volume: volume, suffix: suffix)
        }
    }
    
    private func loadAndPlay(style: SoundStyle, volume: Double, suffix: String) {
        let fileName = getFileName(for: style) + suffix
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else { return }
        
        queue.async { [weak self] in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = Float(volume)
                player.prepareToPlay()
                
                let key = "\(style.rawValue)\(suffix)"
                self?.players[key] = player
                
                player.play()
            } catch {
                print("Failed to load and play sound: \(error)")
            }
        }
    }
    
    func getFileName(for style: SoundStyle) -> String {
        switch style {
        case .system: return ""
        case .snap: return "snap"
        case .click: return "click"
        case .clickLow: return "click_low"
        case .click2: return "click_2"
        case .ping: return "ping"
        case .pingLow: return "ping_low"
        case .ping2: return "ping_2"
        case .ping2Low: return "ping_2_low"
        case .soft: return "soft"
        case .silkey: return "silkey"
        case .marimba: return "marimba"
        case .marimbaLow: return "marimba_low"
        case .miniMarimba: return "mini_marimba"
        case .eightBit: return "8bit"
        case .eightBitLow: return "8bit_low"
        case .drum: return "drum"
        }
    }
}
