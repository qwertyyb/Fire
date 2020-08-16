//
//  FireInputController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit
import Sparkle

var set = false

enum InputMode {
    case zhhans
    case enUS
}

let punctution: [String: String] = [
    ",": "，",
    ".": "。",
    "/": "、",
    ";": "；",
    "'": "‘",
    "[": "［",
    "]": "］",
    "`": "｀",
    "!": "！",
    "@": "‧",
    "#": "＃",
    "$": "￥",
    "%": "％",
    "^": "……",
    "&": "＆",
    "*": "×",
    "(": "（",
    ")": "）",
    "-": "－",
    "_": "——",
    "+": "＋",
    "=": "＝",
    "~": "～",
    "{": "｛",
    "\\": "、",
    "|": "｜",
    "}": "｝",
    ":": "：",
    "\"": "“",
    "<": "《",
    ">": "》",
    "?": "？"
]

class FireInputController: IMKInputController {
    private var  _composedString = ""
    private let _candidatesWindow = FireCandidatesWindow.shared
    private var _mode: InputMode = .zhhans
    private var _lastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)
    private var _originalString = "" {
        didSet {
            if self._page != 1 {
                // code被重新设置时，还原页码为1
                self._page = 1
                return
            }
            NSLog("[FireInputController] original changed: \(self._originalString), refresh window")

            // 必须要mark originalString, 否则在某些APP中会有问题
            let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: NSNotFound, length: 0))
            if let attributes = attrs as? [NSAttributedString.Key: Any] {
                let text = NSAttributedString(string: _originalString, attributes: attributes)
                client()?.setMarkedText(text, selectionRange: selectionRange(), replacementRange: replacementRange())
            }

            if self._originalString.count > 0 {
                self.refreshCandidatesWindow()
                if Fire.shared.cloudinput {
                    Fire.shared.getCandidateFromNetwork(origin: self._originalString, sender: client())
                }
            } else {
                // 没有输入code时，关闭候选框
                _candidatesWindow.close()
            }
        }
    }
    private var _page: Int = 1 {
        didSet(old) {
            guard old == self._page else {
                NSLog("[FireInputHandler] page changed")
                self.refreshCandidatesWindow()
                return
            }
        }
    }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        NSLog("[FireInputController] init")

        super.init(server: server, delegate: delegate, client: inputClient)

        /* NSLog("observer: NetCandidatesUpdate-\(client().bundleIdentifier() ?? "Fire")")
        let notificationName = NSNotification.Name(
            rawValue: "NetCandidatesUpdate-\(client().bundleIdentifier() ?? "Fire")")
        NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: nil
        ) { (notification) in
            guard let list = notification.object as? [Candidate] else { return }
            DispatchQueue.main.async {
                let candidate = list.count > 0 ? list.first! : nil
                self._candidatesWindow.updateNetCandidateView(candidate: candidate)
            }
        } */
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("[FireInputController] handle: \(event.debugDescription)")
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if Utils.shared.checkShiftKeyUp(event)! {
            self.toggleMode()
            return true
        }
        // 监听.flagsChanged事件只为切换中英文，其它情况不处理
        // 当用户已经按下了非shift的修饰键时，不处理
        if event.type == .flagsChanged || (event.modifierFlags != .init(rawValue: 0) && event.modifierFlags != .shift) {
            return false
        }

        // 英文输入模式, 不做任何处理
        if _mode == .enUS {
            return false
        }

        // +/-/arrowdown/arrowup翻页
        let keyCode = event.keyCode
        if _mode == .zhhans && _originalString.count > 0 {
            if keyCode == kVK_ANSI_Equal || keyCode == kVK_DownArrow {
                _page += 1
                return true
            }
            if keyCode == kVK_ANSI_Minus || keyCode == kVK_UpArrow {
                _page = _page > 1 ? _page - 1 : 1
                return true
            }
        }

        // 删除键删除字符
        if keyCode == kVK_Delete {
            if _originalString.count > 0 {
                _originalString = String(_originalString.dropLast())
                return true
            }
            return false
        }

        // 获取输入的字符
        let string = event.characters!

        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if _mode == .zhhans && punctution.keys.contains(string) {
            _composedString = punctution[string]!
            insertText(sender)
            return true
        }

        guard let reg = try? NSRegularExpression(pattern: "^[a-zA-Z]+$") else {
            return true
        }
        let match = reg.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.count)
        )

        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  _originalString.count <= 0 && match == nil {
            NSLog("非字符,不做处理,直接返回")
            return false
        }
        // 当前输入的是英文字符,附加到之前
        if match != nil {
            _originalString += string

            return true
        }

        // 当前输入的是数字,选择当前候选列表中的第N个字符 v
        if let pos = Int(string) {
            let index = pos - 1
            let candidates = self.getCandidates(sender)
            if index < candidates.count {
                _composedString = candidates[index].text
                insertText(sender)
            } else {
                _originalString += string
            }
            return true
        }

        // 回车键输入原字符
        if keyCode == kVK_Return {
            // 插入原字符
            _composedString = _originalString
            insertText(sender)
            return true
        }

        // 空格键输入转换后的中文字符
        if keyCode == kVK_Space {
            let first = self.getCandidates(sender).first
            if first != nil {
                _composedString = first!.text
                insertText(sender)
                _candidatesWindow.close()
            }
            return true
        }
        return false
    }

    func getCandidates(_ sender: Any!) -> [Candidate] {
        let candidates = Fire.shared.getCandidates(origin: self._originalString, page: _page)
        return candidates
    }

    // 更新候选窗口
    func refreshCandidatesWindow() {
        let candidates = getCandidates(client())
        _candidatesWindow.setFrameOrigin(getOriginPoint())
        _candidatesWindow.setCandidates(candidates: candidates, originalString: _originalString)
    }

    override func selectionRange() -> NSRange {
        return NSRange(location: 0, length: _originalString.count)
    }

    override func replacementRange() -> NSRange {
        return NSRange(location: NSNotFound, length: NSNotFound)
    }

    // 往输入框插入当前字符
    func insertText(_ sender: Any!) {
        NSLog("insertText: %@", _composedString)
        let value = NSAttributedString(string: _composedString)
        client().insertText(value, replacementRange: replacementRange())
        clean()
    }

    // 获取当前输入的光标位置
    func getOriginPoint() -> NSPoint {
        var rect = NSRect()
        client().attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        return rect.origin
    }

    func toggleMode() {
        NSLog("[FireInputController]toggle mode: \(_mode)")

        // 把当前未上屏的原始code上屏处理
        _composedString = _originalString
        insertText(nil)

        _mode = _mode == .zhhans ? InputMode.enUS : InputMode.zhhans

        let text = _mode == .zhhans ? "中" : "A"

        // 在输入坐标处，显示中英切换提示
        Utils.shared.showTips(text, origin: getOriginPoint())
    }

    override func composedString(_ sender: Any!) -> Any! {
        return NSAttributedString(string: _composedString)
    }

    func clean() {
        NSLog("[FireInputController] clean")
        _originalString = ""
        _composedString = ""
        _page = 1
        _candidatesWindow.close()
    }

    override func inputControllerWillClose() {
        clean()
    }

    override func hidePalettes() {
        clean()
    }

    override func activateServer(_ sender: Any!) {
        NSLog("[FireInputController] active server: \(client()!.bundleIdentifier()!)")
    }

    override func deactivateServer(_ sender: Any!) {
        NSLog("[FireInputController] deactivate server: \(client()!.bundleIdentifier()!)")
        clean()
    }

    /* -- menu actions start -- */

    @objc func openAbout (_ sender: Any!) {
        NSLog("open about")
        DispatchQueue.main.async {
            NSLog("check updates")
            NSApp.orderFrontStandardAboutPanel(sender)
        }
    }

    @objc func checkForUpdates(_ sender: Any!) {
        SUUpdater.shared()?.checkForUpdates(sender)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "关于业火输入法", action: #selector(openAbout(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "检查更新", action: #selector(checkForUpdates(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "首选项", action: #selector(showPreferences(_:)), keyEquivalent: ""))
        return menu
    }

}
