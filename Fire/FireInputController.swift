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
    private var inputMode: InputMode {
        get { Fire.shared.inputMode }
        set(value) { Fire.shared.inputMode = value }
    }

    private var temp: (
        observerList: [NSObjectProtocol],
        monitorList: [Any?]
    ) = (
        observerList: [],
        monitorList: []
    )

    private var _originalString = "" {
        didSet {
            if self.curPage != 1 {
                // code被重新设置时，还原页码为1
                self.curPage = 1
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
            if Fire.shared.setFirstCandidate(wbcode: _originalString, candidate: _candidates[num - 1]) {
                self.curPage = 1
                self.refreshCandidatesWindow()
                return true
            }
            return nil
        }
        return nil
    }

    private func flagChangedHandler(event: NSEvent) -> Bool? {
        if Defaults[.disableEnMode] {
            return nil
        }
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if Utils.shared.toggleInputModeKeyUpChecker.check(event) {
            NSLog("[FireInputController]toggle mode: \(inputMode)")

            // 把当前未上屏的原始code上屏处理
            insertText(_originalString)

            Fire.shared.toggleInputMode()

            let text = inputMode == .zhhans ? "中" : "英"

            // 在输入坐标处，显示中英切换提示
            Utils.shared.toast?.show(text, position: getOriginPoint())
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

    private func pageKeyHandler(event: NSEvent) -> Bool? {
        // +/-/arrowdown/arrowup翻页
        let keyCode = event.keyCode
        if inputMode == .zhhans && _originalString.count > 0 {
            if keyCode == kVK_ANSI_Equal || keyCode == kVK_DownArrow {
                curPage = _hasNext ? curPage + 1 : curPage
                return true
            }
            if keyCode == kVK_ANSI_Minus || keyCode == kVK_UpArrow {
                curPage = curPage > 1 ? curPage - 1 : 1
                return true
            }
        }
        return nil
    }

    private func deleteKeyHandler(event: NSEvent) -> Bool? {
        let keyCode = event.keyCode
        // 删除键删除字符
        if keyCode == kVK_Delete {
            if _originalString.count > 0 {
                _originalString = String(_originalString.dropLast())
                return true
            }
            return false
        }
        return nil
    }

    private func punctutionKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        let string = event.characters!

        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if inputMode == .zhhans, let result = Fire.shared.transformPunctution(string) {
            insertText(result)
            return true
        }
        return nil
    }

    private func charKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        let string = event.characters!

        guard let reg = try? NSRegularExpression(pattern: "^[a-zA-Z]+$") else {
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
        if let pos = Int(string), _originalString.count > 0 {
            let index = pos - 1
            if index < _candidates.count {
                insertCandidate(_candidates[index])
            } else {
                _originalString += string
            }
            return true
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

    // ---- handlers end -------

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("[FireInputController] handle: \(event.debugDescription)")

        let handler = Utils.shared.processHandlers(handlers: [
            hotkeyHandler,
            flagChangedHandler,
            enModeHandler,
            pageKeyHandler,
            deleteKeyHandler,
            charKeyHandler,
            numberKeyHandlder,
            punctutionKeyHandler,
            escKeyHandler,
            enterKeyHandler,
            spaceKeyHandler
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
        if Defaults[.wubiAutoCommit] && _candidates.count == 1 && _originalString.count >= 4 {
            // 满4码唯一候选词自动上屏
            if let candidate = _candidates.first {
                insertCandidate(candidate)
                return
            }
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
        clean()
    }

    // 获取当前输入的光标位置
    private func getOriginPoint() -> NSPoint {
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

    func notificationList() -> [NotificationObserver] {
        return [
            (Fire.candidateSelected, { notification in
                if let candidate = notification.userInfo?["candidate"] as? Candidate {
                    self.insertCandidate(candidate)
                }
            }),
            (Fire.prevPageBtnTapped, { _ in self.curPage = self.curPage > 1 ? self.curPage - 1 : 1 }),
            (Fire.nextPageBtnTapped, { _ in self.curPage = self._hasNext ? self.curPage + 1 : self.curPage }),
            (Fire.inputModeChanged, { notification in
                if self._originalString.count > 0, notification.userInfo?["val"] as? InputMode == InputMode.enUS {
                    self.insertText(self._originalString)
                }
            })
        ]
    }

    /**
     * 根据当前输入的应用改变输入模式
     */
    private func activeClientInputMode() {
        guard let identifier = client()?.bundleIdentifier() else { return }
        if let appSetting = Defaults[.appSettings][identifier],
           let mode = InputMode(rawValue: appSetting.inputModeSetting.rawValue) {
            print("[FireInputController] activeClientInputMode from setting : \(identifier), \(mode)")
            Fire.shared.toggleInputMode(mode)
            return
        }
        if !Defaults[.keepAppInputMode] { return }
        // 启用APP缓存设置
        if let appSetting = Fire.shared.appSettingCache.get(bundleIdentifier: identifier),
           let mode = InputMode(rawValue: appSetting.inputModeSetting.rawValue) {
            print("[FireInputController] activeClientInputMode from cache: \(identifier), \(mode)")
            Fire.shared.toggleInputMode(mode)
        }
    }

    /**
     * 由于使用recognizedEvents在一些场景下不能监听到flagChanged事件，比如保存文件场景
     * 所以这里需要使用NSEvent.addGlobalMonitorForEvents监听shift键被按下
     */
    override func activateServer(_ sender: Any!) {
        NSLog("[FireInputController] activate server: \(client()?.bundleIdentifier() ?? sender.debugDescription)")

        // 监听candidateView点击，翻页事件
        notificationList().forEach { (observer) in temp.observerList.append(NotificationCenter.default.addObserver(
            forName: observer.name, object: nil, queue: nil, using: observer.callback
        ))}
        if Defaults[.disableEnMode] {
            Fire.shared.toggleInputMode(.zhhans)
            return
        }

        activeClientInputMode()
        temp.monitorList.append(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            if !InputSource.shared.isSelected() {
                return self.clearEventListener()
            }
            _ = self.handle(event, client: self.client())
        })
    }
    func clearEventListener() {
        temp.monitorList.forEach { (monitor) in
            if let m = monitor {
                NSEvent.removeMonitor(m)
            }
        }
        temp.observerList.forEach { (observer) in
            NotificationCenter.default.removeObserver(observer)
        }
        temp.monitorList = []
        temp.observerList = []
    }
    override func deactivateServer(_ sender: Any!) {
        NSLog("[FireInputController] deactivate server: \(client()?.bundleIdentifier() ?? "no client deactivate")")
        if let identifier = client()?.bundleIdentifier(), !Defaults[.disableEnMode] {
        // 缓存当前输入模式
            Fire.shared.appSettingCache.add(
                bundleIdentifier: identifier,
                setting: ApplicationSettingItem(
                    bundleId: identifier,
                    inputMs: InputModeSetting(rawValue: inputMode.rawValue)!
                )
            )
        }
        clean()
        clearEventListener()
    }
}
