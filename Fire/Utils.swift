//
//  checkShiftUp.swift
//  Fire
//
//  Created by 虚幻 on 2020/8/15.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Defaults
import InputMethodKit
import SwiftUI

enum HandlerStatus {
    case next
    case stop
}

class Utils {
    var toggleInputModeKeyUpChecker = ModifierKeyUpChecker(Defaults[.toggleInputModeKey])

    var toast: ToastWindowProtocol?

    private func initToastWindow() {
        toast = Defaults[.inputModeTipWindowType] == .centerScreen
            ? ToastWindow()
           : Defaults[.inputModeTipWindowType] == .followInput
               ? TipsWindow()
               : nil
    }
    init() {
        Defaults.observe(keys: .inputModeTipWindowType, .candidateCount) { () in
            self.initToastWindow()
        }.tieToLifetime(of: self)
        Defaults.observe(.toggleInputModeKey) { (val) in
            let modifier = val.newValue
            print("modifier: ", modifier)
            self.toggleInputModeKeyUpChecker = ModifierKeyUpChecker(modifier)
        }.tieToLifetime(of: self)
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
    
    // 根据上次输入的字符，判断插入的新字符是否要前加空格
    func shouldConcatWithWhitespace(_ lastText: String, _ nextText: String) -> Bool {
        NSLog("[Utils] shouldConcatWithWhitespace, lastText: \(lastText), nextText: \(nextText)")
        if lastText.count <= 0 || nextText.count <= 0 {
            return false
        }
        guard let firstEnReg = try? NSRegularExpression(pattern: "[a-zA-Z0-9]$"),
              let nextCnReg = try? NSRegularExpression(pattern: "^[\\u4e00-\\u9fa5]") else {
            return false
        }
        if firstEnReg.numberOfMatches(in: lastText, range: NSMakeRange(0, lastText.count)) > 0
            && nextCnReg.numberOfMatches(in: nextText, range: NSMakeRange(0, nextText.count)) > 0 {
            return true
        }
        guard let firstCnReg = try? NSRegularExpression(pattern: "[\\u4e00-\\u9fa5]$"),
              let nextEnReg = try? NSRegularExpression(pattern: "^[a-zA-Z0-9]") else {
            return false
        }
        return firstCnReg.numberOfMatches(in: lastText, range: NSMakeRange(0, lastText.count)) > 0
            && nextEnReg.numberOfMatches(in: nextText, range: NSMakeRange(0, nextText.count)) > 0
    }

    static let shared = Utils()
}
