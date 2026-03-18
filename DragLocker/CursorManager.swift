import AppKit
import SwiftUI

class CursorManager {
    static let shared = CursorManager()
    
    private var cursorWindow: NSWindow?
    
    init() {
        setupCursorWindow()
    }
    
    private func setupCursorWindow() {
        // ウィンドウサイズ
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

        // 新たに追加されたPointer_Locked画像を本来のサイズで表示
        let contentView = NSHostingView(rootView:
            ZStack(alignment: .center) {
                Image("Pointer_Locked")
            }
            .frame(width: 32, height: 32)
        )

        window.contentView = contentView
        self.cursorWindow = window
    }

    /// インジケーターを表示
    func showCustomCursor() {
        guard let window = cursorWindow else { return }
        updatePosition()
        window.orderFront(nil)
    }

    /// インジケーターを非表示
    func hideCustomCursor() {
        cursorWindow?.orderOut(nil)
    }

    /// ウィンドウの位置を現在のマウス位置の右側に更新
    func updatePosition() {
        guard let window = cursorWindow else { return }

        // AppKitの座標系（左下が0,0）でマウス位置を取得
        let mouseLocation = NSEvent.mouseLocation

        // 横：以前の+2ptを維持
        // 縦：以前の-15ptから1pt上へ移動（-14pt）
        let newOrigin = NSPoint(
            x: mouseLocation.x + 2,
            y: mouseLocation.y - 14
        )

        window.setFrameOrigin(newOrigin)
    }
    }
