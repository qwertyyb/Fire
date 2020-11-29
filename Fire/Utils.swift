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
import Defaults

enum HandlerStatus {
    case next
    case stop
}

class Utils {
    var toggleInputModeKeyUpChecker = ModifierKeyUpChecker(.shift)

    var toast: ToastWindowProtocol?

    private func initToastWindow() {
        toast = Defaults[.inputModeTipWindowType] == .centerScreen
            ? ToastWindow()
           : Defaults[.inputModeTipWindowType] == .followInput
               ? TipsWindow()
               : nil
    }
    private var toastSettingObserver: Defaults.Observation!
    private var toggleInputModeKeyObserver: Defaults.Observation!
    init() {
        toastSettingObserver = Defaults.observe(keys: .inputModeTipWindowType, .candidateCount) { () in
            self.initToastWindow()
        }
        toggleInputModeKeyObserver = Defaults.observe(.toggleInputModeKey) { (val) in
            let modifier = NSEvent.ModifierFlags(rawValue: val.newValue)
            print("modifier: ", modifier)
            self.toggleInputModeKeyUpChecker = ModifierKeyUpChecker(modifier)
        }
    }
    deinit {
        toastSettingObserver.invalidate()
        toggleInputModeKeyObserver.invalidate()
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
