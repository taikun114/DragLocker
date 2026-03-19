import AppKit
import AVFoundation
import Foundation

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
}

class SoundManager {
    static let shared = SoundManager()
    
    // スタイルと方向（up/down）の組み合わせをキーにしてプレイヤーをキャッシュ
    private var players: [String: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "com.draglocker.soundmanager", qos: .utility)
    
    private init() {
        preloadSounds()
    }
    
    private func preloadSounds() {
        // バックグラウンドで全サウンドをプリロード
        queue.async {
            for style in SoundStyle.allCases where style != .system {
                for suffix in ["_up", "_down"] {
                    let baseName = self.getFileName(for: style)
                    let fileName = baseName + suffix
                    if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
                        do {
                            let player = try AVAudioPlayer(contentsOf: url)
                            player.prepareToPlay()
                            let key = "\(style.rawValue)\(suffix)"
                            self.players[key] = player
                        } catch {
                            print("Failed to preload sound: \(fileName), error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func play(style: SoundStyle, volume: Double, isLocked: Bool, isInverted: Bool = false) {
        if style == .system {
            NSSound.beep()
            return
        }
        
        let effectiveIsLocked = isInverted ? !isLocked : isLocked
        let suffix = effectiveIsLocked ? "_up" : "_down"
        playSpecific(style: style, volume: volume, suffix: suffix)
    }
    
    func preview(style: SoundStyle, volume: Double, isInverted: Bool = false) {
        if style == .system {
            NSSound.beep()
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
            player.volume = Float(volume)
            player.currentTime = 0
            player.play()
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
