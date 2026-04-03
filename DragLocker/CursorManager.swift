import AppKit
import SwiftUI

class CursorManager {
    static let shared = CursorManager()
    
    private var cursorWindow: NSWindow?
    
    init() {
        setupCursorWindow()
        updateCursorStyle()
    }
    
    private func setupCursorWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 32, height: 32),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.cursorWindow)))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.animationBehavior = .none
        
        self.cursorWindow = window
    }
    
    /// インジケーターを非表示
    func hideCustomCursor() {
        cursorWindow?.orderOut(nil)
    }
    
    /// カーソルのスタイルを更新
    func updateCursorStyle() {
        guard let window = cursorWindow else { return }
        
        let style = EventManager.shared.pointerIconStyle
        
        let contentView = NSHostingView(rootView:
            ZStack(alignment: .center) {
                    if style == .padlock {
                        Image("Pointer_Locked")
                    } else if style == .dot {
                        ZStack(alignment: .center) {
                            Circle().fill(Color.white).frame(width: 8, height: 8)
                            Circle().fill(Color.black).frame(width: 6, height: 6)
                        }
                    } else if style == .largeRing {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 40, height: 40)
                            )
                            .padding(4)
                    }
            }
        )
        // コンテンツのサイズに合わせてウィンドウサイズを自動調整
        contentView.setFrameSize(contentView.fittingSize)
        window.contentView = contentView
        window.setContentSize(contentView.fittingSize)
    }
    
    /// インジケーターを表示
    func showCustomCursor() {
        guard let window = cursorWindow else { return }
        
        updatePosition()
        window.orderFront(nil)
    }
    
    /// 指定された位置にウィンドウの位置を更新
    func updatePosition(to location: CGPoint? = nil) {
        guard let window = cursorWindow else { return }
        
        // 指定がない場合は現在のマウス位置を取得
        let mouseLocation = location ?? NSEvent.mouseLocation
        
        // スタイルごとの位置調整
        let style = EventManager.shared.pointerIconStyle
        let xOffset: Double
        let yOffset: Double
        
        switch style {
        case .padlock:
            xOffset = 12.0
            yOffset = -7.0
        case .dot:
            xOffset = 12.0
            yOffset = -4.0
        case .largeRing:
            xOffset = -24.0
            yOffset = -24.0
        }
        
        let newOrigin = NSPoint(
            x: mouseLocation.x + xOffset,
            y: mouseLocation.y + yOffset
        )
        
        window.setFrameOrigin(newOrigin)
    }
}
