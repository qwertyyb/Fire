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
    let shiftKeyUpChecker = ModifierKeyUpChecker(.shift)

    let toast = ToastWindow()

    init() {
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

    func getScreenFromPoint(_ point: NSPoint) -> NSScreen? {
        // find current screen
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }

    static let shared = Utils()
}
