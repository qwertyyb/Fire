//
//  FireInputController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import SwiftUI
import InputMethodKit
import Sparkle
import Preferences
import Defaults

typealias NotificationObserver = (name: Notification.Name, callback: (_ notification: Notification) -> Void)

class FireInputController: IMKInputController {
    private var _candidates: [Candidate] = []
    private var _hasNext: Bool = false
    private var _lastInputIsNumber = false
    internal var inputMode: InputMode {
        get { Fire.shared.inputMode }
        set(value) { Fire.shared.inputMode = value }
    }

    internal var temp: (
        observerList: [NSObjectProtocol],
        monitorList: [Any?]
    ) = (
        observerList: [],
        monitorList: []
    )

    deinit {
        NSLog("[FireInputController] deinit")
        clean()
    }

    private var _originalString = "" {
        didSet {
            if self.curPage != 1 {
                // code被重新设置时，还原页码为1
                self.curPage = 1
                self.markText()
                return
            }
            NSLog("[FireInputController] original changed: \(self._originalString), refresh window")

            // 建议mark originalString, 否则在某些APP中会有问题
            self.markText()

            self._originalString.count > 0 ? self.refreshCandidatesWindow() : CandidatesWindow.shared.close()
        }
    }
    private var curPage: Int = 1 {
        didSet(old) {
            guard old == self.curPage else {
                NSLog("[FireInputHandler] page changed")
                self.refreshCandidatesWindow()
                return
            }
        }
    }
    func prevPage() {
        self.curPage = self.curPage > 1 ? self.curPage - 1 : 1
    }
    func nextPage() {
        self.curPage = self._hasNext ? self.curPage + 1 : self.curPage
    }

    private func markText() {
        let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: NSNotFound, length: 0))
        if let attributes = attrs as? [NSAttributedString.Key: Any] {
            var selected = self._originalString
            if Defaults[.showCodeInWindow] {
                selected = self._originalString.count > 0 ? " " : ""
            }
            let text = NSAttributedString(string: selected, attributes: attributes)
            client()?.setMarkedText(text, selectionRange: selectionRange(), replacementRange: replacementRange())
        }
    }

    // ---- handlers begin -----

    private func hotkeyHandler(event: NSEvent) -> Bool? {
        if event.type == .flagsChanged {
            return nil
        }
        if event.charactersIgnoringModifiers == nil {
            return nil
        }
        guard let num = Int(event.charactersIgnoringModifiers!) else {
            return nil
        }
        if event.modifierFlags == .control &&
            num > 0 && num <= _candidates.count {
            NSLog("hotkey: control + \(num)")
            DictManager.shared.setCandidateToFirst(query: _originalString, candidate: _candidates[num-1])
            self.curPage = 1
            self.refreshCandidatesWindow()
            return true
        }
        return nil
    }

     func flagChangedHandler(event: NSEvent) -> Bool? {
        if Defaults[.disableEnMode] {
            return nil
        }
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if Utils.shared.toggleInputModeKeyUpChecker.check(event) {
            NSLog("[FireInputController]toggle mode: \(inputMode)")

            // 把当前未上屏的原始code上屏处理
            insertText(_originalString)

            Fire.shared.toggleInputMode()
            return true
        }
        // 监听.flagsChanged事件只为切换中英文，其它情况不处理
        // 当用户已经按下了非shift的修饰键时，不处理
        if event.type == .flagsChanged ||
            (event.modifierFlags != .init(rawValue: 0) &&
             event.modifierFlags != .shift &&
            // 方向键的modifierFlags
             event.modifierFlags != .init(arrayLiteral: .numericPad, .function)
        ) {
            return false
        }
        return nil
    }

    private func enModeHandler(event: NSEvent) -> Bool? {
        // 英文输入模式, 不做任何处理
        if inputMode == .enUS {
            return false
        }
        return nil
    }

    private func predictorHandler(event: NSEvent) -> Bool? {
        if Defaults[.enableDotAfterNumber] && event.keyCode == kVK_ANSI_Period && _lastInputIsNumber {
            insertText(".")
            _lastInputIsNumber = false
            return true
        }
        _lastInputIsNumber = false
        return nil
    }

    private func pageKeyHandler(event: NSEvent) -> Bool? {
        // +/-/arrowdown/arrowup翻页
        let keyCode = event.keyCode
        if inputMode == .zhhans && _originalString.count > 0 {
            let needNextPage = keyCode == kVK_ANSI_Equal ||
                (keyCode == kVK_DownArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_RightArrow && Defaults[.candidatesDirection] == .vertical)
            if needNextPage {
                curPage = _hasNext ? curPage + 1 : curPage
                return true
            }

            let needPrevPage = keyCode == kVK_ANSI_Minus ||
                (keyCode == kVK_UpArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_LeftArrow && Defaults[.candidatesDirection] == .vertical)
            if needPrevPage {
                curPage = curPage > 1 ? curPage - 1 : 1
                return true
            }
        }
        return nil
    }

    private func deleteKeyHandler(event: NSEvent) -> Bool? {
        // 删除键删除字符
        if event.keyCode == kVK_Delete {
            if _originalString.count > 0 {
                _originalString = String(_originalString.dropLast())
                return true
            }
            return false
        }
        return nil
    }

    private func charKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        let string = event.characters!

        guard let reg = try? NSRegularExpression(pattern: "^[a-z]+$") else {
            return nil
        }
        let match = reg.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.count)
        )

        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  _originalString.count <= 0 && match == nil {
            NSLog("非字符,不做处理")
            return nil
        }
        // 当前输入的是英文字符,附加到之前
        if match != nil {
            _originalString += string

            return true
        }
        return nil
    }

    private func numberKeyHandlder(event: NSEvent) -> Bool? {
        // 获取输入的字符
        let string = event.characters!
        // 当前输入的是数字,选择当前候选列表中的第N个字符 v
        if let pos = Int(string) {
            if _originalString.count > 0 {
                let index = pos - 1
                if index < _candidates.count {
                    insertCandidate(_candidates[index])
                } else {
                    _originalString += string
                }
                return true
            }
            _lastInputIsNumber = true
        }
        return nil
    }

    private func escKeyHandler(event: NSEvent) -> Bool? {
        // ESC键取消所有输入
        if event.keyCode == kVK_Escape, _originalString.count > 0 {
            clean()
            return true
        }
        return nil
    }

    private func enterKeyHandler(event: NSEvent) -> Bool? {
        // 回车键输入原字符
        if event.keyCode == kVK_Return && _originalString.count > 0 {
            // 插入原字符
            insertText(_originalString)
            return true
        }
        return nil
    }

    private func spaceKeyHandler(event: NSEvent) -> Bool? {
        // 空格键输入转换后的中文字符
        if event.keyCode == kVK_Space && _originalString.count > 0 {
            if let first = self._candidates.first {
                insertCandidate(first)
            }
            return true
        }
        return nil
    }

    private func punctuationKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        let string = event.characters!
        guard inputMode == .zhhans else { return nil }

        if !Defaults[.disableTempEnMode]
            && _originalString.count <= 0 && string == String(DictManager.shared.tempEnTriggerPunctuation)
                || string != String(DictManager.shared.tempEnTriggerPunctuation)
                    && _originalString.first == DictManager.shared.tempEnTriggerPunctuation {
            _originalString += string
            return true
        }

        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if inputMode == .zhhans, let result = Fire.shared.transformPunctuation(string) {
            insertText(result)
            return true
        }
        return nil
    }

    // ---- handlers end -------

    override func recognizedEvents(_ sender: Any!) -> Int {
        // 当在当前应用下输入时　NSEvent.addGlobalMonitorForEvents 回调不会被调用，需要针对当前app, 使用原始的方式处理flagsChanged事件
        let isCurrentApp = client().bundleIdentifier() == Bundle.main.bundleIdentifier
        var events = NSEvent.EventTypeMask(arrayLiteral: .keyDown)
        if isCurrentApp {
            events = NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged)
        }
        return Int(events.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return }
        NSLog("[FireInputController] handle: \(event.debugDescription)")

        // 在activateServer中有把IMKInputController绑定给CandidatesWindow
        // 然而在实际运行中发现，在Safari地址栏输入部分原码后，再按shift切到英文输入模式下时，候选窗消失了，但原码没有上屏
        // 排查发现，因为shift切换中英文是通过CandidatesWindow调用绑定的inputController方法实现的，而在safari地址栏时，接受键盘输入的inputController
        // 和CandidatesWindow绑定的inputController并不是同一个，所以出现了此问题
        // 这里猜测之所以会出现不一致，是因为在Safari地址栏输入场景下，会有多个TextInputClient而创建多个inputController, activateServer也会多次执行
        // 但是activateServer的调用顺序并不能保证最后调用的就是接受输入事件的TextInputClient对应的inputController
        // 所以仅是在activateServer中绑定inputController是不行的，需要在此处再绑定一下
        CandidatesWindow.shared.inputController = self

        let handler = Utils.shared.processHandlers(handlers: [
            hotkeyHandler,
            flagChangedHandler,
            enModeHandler,
            predictorHandler,
            pageKeyHandler,
            deleteKeyHandler,
            charKeyHandler,
            numberKeyHandlder,
            escKeyHandler,
            enterKeyHandler,
            spaceKeyHandler,
            punctuationKeyHandler
        ])
        return handler(event) ?? false
    }

    func updateCandidates(_ sender: Any!) {
        let (candidates, hasNext) = Fire.shared.getCandidates(origin: self._originalString, page: curPage)
        _candidates = candidates
        _hasNext = hasNext
    }

    // 更新候选窗口
    func refreshCandidatesWindow() {
        updateCandidates(client())
        if Defaults[.wubiAutoCommit] && _candidates.count == 1 && _originalString.count >= 4,
           let candidate = _candidates.first, candidate.type != .placeholder {
            // 满4码唯一候选词自动上屏
            insertCandidate(candidate)
            return
        }
        if !Defaults[.showCodeInWindow] && _candidates.count <= 0 {
            // 不在候选框显示输入码时，如果候选词为空，则不显示候选框
            CandidatesWindow.shared.close()
            return
        }
        let candidatesData = (list: _candidates, hasPrev: curPage > 1, hasNext: _hasNext)
        CandidatesWindow.shared.setCandidates(
            candidatesData,
            originalString: _originalString,
            topLeft: getOriginPoint()
        )
    }

    override func selectionRange() -> NSRange {
        if Defaults[.showCodeInWindow] {
            return NSRange(location: 0, length: min(1, _originalString.count))
        }
        return NSRange(location: 0, length: _originalString.count)
    }

    func insertCandidate(_ candidate: Candidate) {
        insertText(candidate.text)
        let notification = Notification(
            name: Fire.candidateInserted,
            object: nil,
            userInfo: [ "candidate": candidate ]
        )
        // 异步派发事件，防止阻塞当前线程
        NotificationQueue.default.enqueue(notification, postingStyle: .whenIdle)
    }

    // 往输入框插入当前字符
    func insertText(_ text: String) {
        NSLog("insertText: %@", text)
        let value = NSAttributedString(string: text)
        try client()?.insertText(value, replacementRange: replacementRange())
        _lastInputIsNumber = text.last != nil && Int(String(text.last!)) != nil
        clean()
    }

    // 往输入框中插入原始字符
    func insertOriginText() {
        if self._originalString.count > 0 {
            self.insertText(self._originalString)
        }
    }

    // 获取当前输入的光标位置
    func getOriginPoint() -> NSPoint {
        let xd: CGFloat = 0
        let yd: CGFloat = 4
        var rect = NSRect()
        client()?.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        return NSPoint(x: rect.minX + xd, y: rect.minY - yd)
    }

    func clean() {
        NSLog("[FireInputController] clean")
        _originalString = ""
        curPage = 1
        CandidatesWindow.shared.close()
    }
}
