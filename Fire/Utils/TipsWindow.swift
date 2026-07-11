//
//  TipsWindow.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import SwiftUI

class TipsWindow: ToastWindowProtocol {
    private func updateText(text: String) {
        struct TipView: View {
            let text: String
            @Environment(\.colorScheme) var colorScheme
            var body: some View {
                Text(text)
                    .font(.system(size: 14))
                    .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .background(
                        GlassEffectView(cornerRadius: 12, blendingMode: .behindWindow)
                    )
                    .cornerRadius(12)
            }
        }
        guard let win = tipsWindow else {
            return
        }
        win.contentView = NSHostingView(rootView: TipView(text: text))
    }

    private func createTipsWindow() {
        let window = NSWindow()
        window.styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel() + 2))
        tipsWindow = window
    }

    private func clearTimer() {
        hideTipsWindowTimer?.invalidate()
        if tipsWindow?.isVisible ?? false {
            tipsWindow?.close()
            self.tipsWindow = nil
        }
    }

    private func showWindow(_ origin: NSPoint) {
        // 在光标位置基础上加偏移，避免遮挡输入
        let offset = NSPoint(x: 0, y: 48)
        tipsWindow?.setFrameTopLeftPoint(NSPoint(x: origin.x + offset.x, y: origin.y + offset.y))
        tipsWindow?.orderFront(nil)
    }

    func show(_ text: String, position: NSPoint) {
        NSLog("[utils] showTips: \(position)")
        self.clearTimer()
        self.createTipsWindow()
        self.updateText(text: text)
        self.showWindow(position)
        self.resetTimer()
    }
    private func resetTimer() {
        hideTipsWindowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] (_) in
            self?.tipsWindow?.close()
            self?.tipsWindow = nil
        }
    }

    private var tipsWindow: NSWindow?
    private var hideTipsWindowTimer: Timer?

    deinit {
        hideTipsWindowTimer?.invalidate()
    }
}
