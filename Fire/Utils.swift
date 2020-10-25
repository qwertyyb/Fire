//
//  checkShiftUp.swift
//  Fire
//
//  Created by 虚幻 on 2020/8/15.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Cocoa
import SwiftUI
import InputMethodKit

enum HandlerStatus {
    case next
    case stop
}

class Utils {

    var checkShiftKeyUp: (NSEvent) -> Bool?

    func showTips(_ text: String, origin: NSPoint) {
        NSLog("[utils] showTips: \(origin)")
        hideTipsWindowTimer?.invalidate()
        if tipsWindow?.isVisible ?? false {
            tipsWindow?.close()
            self.tipsWindow = nil
        }
        let window = NSWindow()
        window.styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)

        window.contentView = NSHostingView(
            rootView: Text(text)
                .font(.body)
                .padding(6)
        )
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel() + 2))

        window.setFrameTopLeftPoint(origin)
        window.orderFront(nil)
        tipsWindow = window
        hideTipsWindowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (_) in
            self.tipsWindow?.close()
            self.tipsWindow = nil
        }
    }

    private var tipsWindow: NSWindow?
    private var hideTipsWindowTimer: Timer?

    init() {
        // 检查shift键被抬起
        func createCheckShiftKeyUpFn() -> (NSEvent) -> Bool {
            var lastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)
            func checkShiftKeyUp(_ event: NSEvent) -> Bool {
                if event.type == .flagsChanged
                    && event.modifierFlags == .init(rawValue: 0)
                    && lastModifier == .shift {  // shift键抬起
                    lastModifier = event.modifierFlags
                    return true
                }
                lastModifier = event.type == .flagsChanged ? event.modifierFlags : .init(rawValue: 0)
                return false
            }
            return  checkShiftKeyUp
        }
        self.checkShiftKeyUp = createCheckShiftKeyUpFn()
    }

    func processHandlers<T>(
        handlers: [(NSEvent) -> T?]
    ) -> ((NSEvent) -> T?) {
        func handleFn(event: NSEvent) -> T? {
            for handler in handlers {
                if let result = handler(event) {
                    return result
                }
            }
            return nil
        }
        return handleFn
    }

    static let shared = Utils()
}
