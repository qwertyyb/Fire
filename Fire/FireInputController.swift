//
//  FireInputController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import SwiftUI
import InputMethodKit
import Defaults

typealias NotificationObserver = (name: Notification.Name, callback: (_ notification: Notification) -> Void)

class FireInputController: IMKInputController, InputContext  {
    var curPage: Int = 0
    
    var origin: String = ""
    
    var candidates: [Candidate] = []
    
    var hasNext: Bool = true
    
    var selectedIndex: Int = 0
    
    var session = Engine.shared.createSession(dict: DictManager.shared, config: FireEngineConfig.shared)
    
    func commit(_ text: String) {
        FireLog.input.debug("commit: \(text)")
        self.insertText(text)
    }
    
    func commitCandidate(_ candidate: Candidate, confirmed: Bool) {
        self.insertCandidate(candidate, confirmed: confirmed)
        self.candidates = []
        clean()
    }
    
    func getTextBefore(_ count: Int = 1) -> String {
        // 中文输入模式下，markedRange 会跟随输入字符变化
        // 不同APP下，对selectedRange的location处理不同，有的把location放在组字区后，比如备忘录APP，有的把location放在组字区前，比如Chrome浏览器，此处根据大小判断一下
        let selectedRange = client().selectedRange()
        var markedRange = client().markedRange()
        // 默认认为 location 在组字区后
        if markedRange.location == NSNotFound {
            markedRange = NSRange(location: 0, length: 0)
        }
        var previousLocation = selectedRange.location - markedRange.length - 1
        // 某些场景下，markedRange的location和length不正常，此处按大小判断一下
        if selectedRange.location < markedRange.location + markedRange.length {
            // selectedRange的location在组字区前
            previousLocation = selectedRange.location - 1
        }
        if previousLocation <= 0 {
            return ""
        }
        return client().attributedSubstring(from: NSMakeRange(previousLocation, 1))?.string ?? ""
    }
    
    func showMessage(_ message: String) {
        Utils.shared.showMessage(message)
    }
    
    func prevPage() {
        var inputContext: any InputContext = self
        if session.prevPage(&inputContext) {
            refreshCandidatesWindow()
        }
    }
    func nextPage() {
        var inputContext: any InputContext = self
        if session.nextPage(&inputContext) {
            refreshCandidatesWindow()
        }
    }
    
    // 字母正则判断：提为 static let 避免热路径（每次按键）重复编译正则表达式，提升输入响应性能
    private static let letterRegex = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")

    deinit {
        FireLog.input.debug("deinit")
        // 清理由 CandidatesWindow 管理的观察者
        CandidatesWindow.shared.close()
    }

    private func markText() {
        let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: NSNotFound, length: 0))
        if let attributes = attrs as? [NSAttributedString.Key: Any] {
            var selected = self.origin
            if Defaults[.showCodeInWindow] {
                selected = self.origin.count > 0 ? " " : ""
            }
            let text = NSAttributedString(string: selected, attributes: attributes)
            client()?.setMarkedText(text, selectionRange: selectionRange(), replacementRange: replacementRange())
        }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        // 当在当前应用下输入时　NSEvent.addGlobalMonitorForEvents 回调不会被调用，需要针对当前app, 使用原始的方式处理flagsChanged事件
        let isCurrentApp = client().bundleIdentifier() == Bundle.main.bundleIdentifier
        var events = NSEvent.EventTypeMask(arrayLiteral: .keyDown)
        if isCurrentApp {
            events = NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged)
        }
        return Int(events.rawValue)
    }
    
    func transformToKeyInput(_ event: NSEvent) -> KeyInput {
        if Fire.shared.modifierKeyPressChecker.check(event) {
            return KeyInput(
                type: .modifierPress,
                keyCode: event.keyCode,
                characters: event.characters,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            )
        }
        return KeyInput(event: event)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return false }
        
        FireLog.input.debug("handle: \(event.debugDescription, privacy: .public)")

        // 在activateServer中有把IMKInputController绑定给CandidatesWindow
        // 然而在实际运行中发现，在Safari地址栏输入部分原码后，再按shift切到英文输入模式下时，候选窗消失了，但原码没有上屏
        // 排查发现，因为shift切换中英文是通过CandidatesWindow调用绑定的inputController方法实现的，而在safari地址栏时，接受键盘输入的inputController
        // 和CandidatesWindow绑定的inputController并不是同一个，所以出现了此问题
        // 这里猜测之所以会出现不一致，是因为在Safari地址栏输入场景下，会有多个TextInputClient而创建多个inputController, activateServer也会多次执行
        // 但是activateServer的调用顺序并不能保证最后调用的就是接受输入事件的TextInputClient对应的inputController
        // 所以仅是在activateServer中绑定inputController是不行的，需要在此处再绑定一下
        if CandidatesWindow.shared.inputController !== self {
            CandidatesWindow.shared.inputController = self
        }
        Fire.shared.activeInputController = self
        
        let keyInput = transformToKeyInput(event)
        
        var context: any InputContext = self
        let result = session.handle(keyInput, context: &context) {} ?? false
        
        self.markText()
        self.refreshCandidatesWindow()
        
        return result
    }
    
    override func commitComposition(_ sender: Any!) {
        FireLog.input.debug("commitComposition")
        var inputContext: any InputContext = self
        session.commitSelected(&inputContext, reason: .auto)
    }

    // 更新候选窗口
    // 逻辑顺序：获取候选 → 满4码唯一候选自动上屏 → 无候选且不显示输入码时关闭窗口 → 显示候选窗
    func refreshCandidatesWindow() {
        if !Defaults[.showCodeInWindow] && candidates.count <= 0 {
            // 不在候选框显示输入码时，如果候选词为空，则不显示候选框
            CandidatesWindow.shared.close()
            return
        }
        FireLog.input.debug("refreshCandidatesWindow, origin: \(self.origin), \(self.candidates)")
        if origin.isEmpty && candidates.isEmpty {
            CandidatesWindow.shared.close()
            return
        }
        let candidatesData = (list: candidates, hasPrev: curPage > 1, hasNext: hasNext)
        CandidatesWindow.shared.setCandidates(
            candidatesData,
            originalString: origin,
            topLeft: getOriginPoint(),
            selectedIndex: selectedIndex
        )
    }

    override func selectionRange() -> NSRange {
        FireLog.input.debug("selectionRange")
        if Defaults[.showCodeInWindow] {
            return NSRange(location: 0, length: min(1, origin.count))
        }
        return NSRange(location: 0, length: origin.count)
    }

    func insertCandidate(_ candidate: Candidate, confirmed: Bool = false) {
        // 获取光标位置（参考 TipsWindow 定位方式）
        let cursorPoint = getOriginPoint()

        insertText(candidate.text)

        // 中文上屏时触发庆祝动画
        if candidate.type != .placeholder, candidate.text.contains(where: { $0.isChineseChar }) {
            Defaults[.celebrationEffect].show(at: cursorPoint)
        }

        let notification = Notification(
            name: Fire.candidateInserted,
            object: nil,
            userInfo: [ "candidate": candidate, "confirmed": confirmed ]
        )
        // 异步派发事件，防止阻塞当前线程
        NotificationQueue.default.enqueue(notification, postingStyle: .whenIdle)
    }

    // 往输入框插入当前字符
    func insertText(_ text: String) {
        FireLog.input.debug("insertText: \(text), \(self.client()?.bundleIdentifier() ?? "")")
        if text.count > 0 {
            var newText = text
            let textBefore = getTextBefore(1)
            if Defaults[.enableWhitespaceBetweenZhEn] && Utils.shared.shouldConcatWithWhitespace(textBefore, text) {
                newText = " " + newText
                FireLog.input.debug("insertCandidate should append whitespace: \(newText)")
            }
            let value = NSAttributedString(string: newText)
            FireLog.input.debug("insertText, \(self.replacementRange())")
            client()?.insertText(value, replacementRange: replacementRange())
            if Engine.isPair(newText) {
                DispatchQueue.main.async {
                    self.moveCursor(-1)
                }
            }
        }
        clean()
    }
    
    func moveCursor(_ offset: Int) {
        // offset 负值往前移，正值往后移
        guard let client = client() else { return }
        FireLog.input.debug("moveCursor \(String(describing: client.attributedSubstring(from: NSMakeRange(0, 10)))) \(offset, privacy: .public), selectedRange: \(String(describing: client.selectedRange()), privacy: .public), markedRange: \(String(describing: client.markedRange()), privacy: .public), length: \(client.length(), privacy: .public)")
        let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: NSNotFound, length: 0))
        let curPos = client.selectedRange().location
        let expectPos = curPos + offset
        // 理论上此处应当判断位置是否超过 client.length()，但是发现在 Chrome、Electron 等应用上，client.length() 返回0，不存在判断过界的条件
        // 经过实测发现，即使向后超过当前文本框的文本长度，也不会报错，所以此处不再进行过界的判断
        if expectPos < 0 { return }
        let range = NSMakeRange(expectPos, 0)
        if let attributes = attrs as? [NSAttributedString.Key: Any] {
            let text = NSAttributedString(string: " ", attributes: attributes)
            client.setMarkedText(text, selectionRange: selectionRange(), replacementRange: range)
            DispatchQueue.main.async {
                client.setMarkedText("", selectionRange: self.selectionRange(), replacementRange: range)
            }
        }
    }

    // 往输入框中插入原始字符
    func insertOriginText() {
        if self.origin.count > 0 {
            self.insertText(self.origin)
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
        FireLog.input.debug("clean")
        origin = ""
        curPage = 1
        selectedIndex = 0
        candidates = []
        CandidatesWindow.shared.close()
    }
}

extension Character {
    // 是否为 CJK 统一表意文字(常用汉字区)
    var isChineseChar: Bool {
        unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }
}
