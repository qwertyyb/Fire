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
import Defaults

typealias NotificationObserver = (name: Notification.Name, callback: (_ notification: Notification) -> Void)

class FireInputController: IMKInputController {
    // 字母正则判断：提为 static let 避免热路径（每次按键）重复编译正则表达式，提升输入响应性能
    private static let letterRegex = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
    private var _candidates: [Candidate] = []
    private var _hasNext: Bool = false
    private var _lastInputIsNumber = false
    private var _lastInputText = ""
    // 待二次确认删除的候选词，非 nil 时候选窗处于删除确认态
    private var _pendingDeleteCandidate: Candidate?
    // 组词模式下当前组合的字数，非 nil 时处于"快速加词"组词态
    private var _combineCount: Int?
    // 方向键移动高亮的候选词索引
    var selectedIndex: Int = 0
    internal var inputMode: InputMode {
        get { Fire.shared.inputMode }
        set(value) { Fire.shared.inputMode = value }
    }

    deinit {
        NSLog("[FireInputController] deinit")
        // 清理由 CandidatesWindow 管理的观察者
        CandidatesWindow.shared.close()
    }

    private var _originalString = "" {
        didSet {
            selectedIndex = 0
            if self.curPage != 1 {
                // code被重新设置时，还原页码为1
                self.curPage = 1
                self.markText()
                return
            }
            NSLog("[FireInputController] original changed: \(self._originalString), refresh window")

            // 建议mark originalString, 否则在某些APP中会有问题
            self.markText()

            if self._originalString.count > 0 {
                self.refreshCandidatesWindow()
            } else {
                CandidatesWindow.shared.close()
            }
        }
    }
    private var curPage: Int = 1 {
        didSet(old) {
            guard old != self.curPage else { return }
            NSLog("[FireInputHandler] page changed")
            self.refreshCandidatesWindow()
        }
    }
    func prevPage() {
        guard curPage > 1 else { return }
        curPage -= 1
        selectedIndex = 0
    }
    func nextPage() {
        guard _hasNext else { return }
        curPage += 1
        selectedIndex = 0
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

    // 组词模式下用一个空格占位标记合成串，保持合成态，确保方向键等被输入法消费而不传给应用
    private func markCombineText() {
        let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: NSNotFound, length: 0))
        if let attributes = attrs as? [NSAttributedString.Key: Any] {
            let text = NSAttributedString(string: " ", attributes: attributes)
            client()?.setMarkedText(text, selectionRange: selectionRange(), replacementRange: replacementRange())
        }
    }
    
    private func getPreviousText(_ count: Int = 1) -> String {
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

    // ---- handlers begin -----

    private func hotkeyHandler(event: NSEvent) -> Bool? {
        NSLog("[FireInputController] hotkeyHandler")
        if event.type == .flagsChanged {
            return nil
        }

        // Ctrl+Shift+数字：从词库删除对应候选词
        // 按住 Shift 时数字键的 charactersIgnoringModifiers 会变成符号(如 Shift+1 -> !)，
        // 无法用 Int 解析，这里改用 keyCode 映射数字
        let digitByKeyCode: [UInt16: Int] = [
            UInt16(kVK_ANSI_1): 1, UInt16(kVK_ANSI_2): 2, UInt16(kVK_ANSI_3): 3,
            UInt16(kVK_ANSI_4): 4, UInt16(kVK_ANSI_5): 5, UInt16(kVK_ANSI_6): 6,
            UInt16(kVK_ANSI_7): 7, UInt16(kVK_ANSI_8): 8, UInt16(kVK_ANSI_9): 9
        ]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let deleteModifiers: NSEvent.ModifierFlags = [.control, .shift]
        if modifiers == deleteModifiers,
           let deleteIndex = digitByKeyCode[event.keyCode],
           deleteIndex <= _candidates.count {
            let target = _candidates[deleteIndex - 1]
            if target.type != .placeholder {
                NSLog("hotkey: control + shift + \(deleteIndex), delete confirm: \(target.text)")
                if _pendingDeleteCandidate == target {
                    // 再按一次同一组合键 = 确认删除
                    confirmDelete(target)
                } else {
                    // 首次按下或切换删除目标，进入二次确认态
                    _pendingDeleteCandidate = target
                    showDeleteConfirm(target)
                }
            }
            return true
        }
        // Ctrl+= ：在无正在输入原码时进入"快速加词"组词模式
        if modifiers == .control, event.keyCode == UInt16(kVK_ANSI_Equal), _originalString.isEmpty {
            if Fire.shared.recentCommittedTexts.count >= 2 {
                _combineCount = 2
                markCombineText()
                showCombinePreview()
            } else {
                Utils.shared.showMessage("请先输入至少两个字，再按 control+= 组词")
            }
            return true
        }
        guard let chars = event.charactersIgnoringModifiers, let num = Int(chars) else {
            return nil
        }
        // Ctrl+Option+数字：置顶候选词
        if modifiers == [.control, .option] &&
            num > 0 && num <= _candidates.count {
            NSLog("hotkey: control + option + \(num)")
            DictManager.shared.setCandidateToFirst(query: _originalString, candidate: _candidates[num-1])
            self.curPage = 1
            self.refreshCandidatesWindow()
            return true
        }
        return nil
    }

    // 在候选窗中以 placeholder 形式展示删除确认提示
    private func showDeleteConfirm(_ target: Candidate) {
        let tip = Candidate(
            code: _originalString,  // code 设为原码，避免 getShownCode 显示多余的"()"
            text: "",               // text 置空，防止鼠标点按候选时误插入文字
            type: .placeholder,
            label: "确认删除「\(target.text)」? Enter键确认， Esc键取消"
        )
        CandidatesWindow.shared.setCandidates(
            (list: [tip], hasPrev: false, hasNext: false),
            originalString: _originalString,
            topLeft: getOriginPoint()
        )
    }

    // 确认删除并恢复正常候选窗
    private func confirmDelete(_ target: Candidate) {
        NSLog("[FireInputController] confirmDelete: \(target.text)")
        DictManager.shared.deleteCandidate(target)
        Utils.shared.showMessage("已删除「\(target.text)」")
        _pendingDeleteCandidate = nil
        self.curPage = 1
        self.refreshCandidatesWindow()
    }

    // 删除确认态下的按键处理：回车确认、Esc 取消、组合键透传、其它键取消并照常处理
    private func deleteConfirmHandler(event: NSEvent) -> Bool? {
        guard let pending = _pendingDeleteCandidate else { return nil }
        // 放行 flagsChanged(如 shift 切中英文)，相关清理由 clean() 完成
        if event.type == .flagsChanged { return nil }
        // 回车确认删除
        if event.keyCode == kVK_Return {
            confirmDelete(pending)
            return true
        }
        // 组合键(Ctrl+Shift+数字)透传给 hotkeyHandler 处理：同号确认、换号切目标
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == [.control, .shift] {
            return nil
        }
        // 其余按键一律取消确认，恢复真实候选
        _pendingDeleteCandidate = nil
        self.refreshCandidatesWindow()
        // Esc 仅取消，不清空已输入的原码
        if event.keyCode == kVK_Escape {
            return true
        }
        // 其它键取消后继续走正常处理链
        return nil
    }

    // 组词模式当前合成的文本(最近 count 个上屏项按原顺序拼接)
    private func combineText(_ count: Int) -> String {
        return Fire.shared.recentCommittedTexts.suffix(count).joined()
    }

    // 在候选窗中以 placeholder 形式预览组词结果及其五笔码
    private func showCombinePreview() {
        guard let count = _combineCount else { return }
        let text = combineText(count)
        // 五笔码显示在候选窗原码区；code 与 origin 保持一致以避免出现多余的"()"
        let codeStr = DictManager.shared.makeWubiWordCode(for: text) ?? "无法取码"
        let tip = Candidate(
            code: codeStr,
            text: "",
            type: .placeholder,
            label: "【\(text)】，←键增字， →键减字，Enter键确认， Esc键取消"
        )
        CandidatesWindow.shared.setCandidates(
            (list: [tip], hasPrev: false, hasNext: false),
            originalString: codeStr,
            topLeft: getOriginPoint()
        )
    }

    // 确认组词：生成五笔码并写入用户词库
    private func confirmCombine() {
        guard let count = _combineCount else { return }
        let text = combineText(count)
        if let code = DictManager.shared.makeWubiWordCode(for: text) {
            // 如果该词已被屏蔽，取消屏蔽后继续添加为用户词
            if DictManager.shared.isBlocked(text) {
                DictManager.shared.unblockWord(text)
            }
            _ = DictManager.shared.prependCandidate(
                candidate: Candidate(code: code, text: text, type: .user))
            // 组词成功时显示编码提示，方便用户验证
            Utils.shared.showMessage("已添加新词【\(text)】\(code)")
            NotificationQueue.default.enqueue(
                Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
        } else {
            Utils.shared.showMessage("无法为【\(text)】生成五笔码")
        }
        // clean() 会清空 _originalString 触发 markText 清除组词占位的合成串，并重置 _combineCount、关闭候选窗
        clean()
    }

    // 组词模式下的按键处理：Left 增、Right 减、Enter 确认、Esc 退出，其它键退出后照常处理
    private func combineHandler(event: NSEvent) -> Bool? {
        guard let count = _combineCount else { return nil }
        if event.type == .flagsChanged { return nil }
        let bufCount = Fire.shared.recentCommittedTexts.count
        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            _combineCount = min(count + 1, bufCount)
            showCombinePreview()
            return true
        case kVK_RightArrow:
            _combineCount = max(count - 1, 2)
            showCombinePreview()
            return true
        case kVK_Return:
            confirmCombine()
            return true
        case kVK_Escape:
            clean()
            return true
        default:
            // 其它键退出组词模式后继续走正常处理链
            clean()
            return nil
        }
    }

     func flagChangedHandler(event: NSEvent) -> Bool? {
         NSLog("[FireInputController] flagChangedHandler")
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if !Defaults[.disableEnMode] && Utils.shared.toggleInputModeKeyUpChecker.check(event) {
            NSLog("[FireInputController]toggle mode: \(inputMode)")

            // 把当前未上屏的原始code上屏处理
            insertText(_originalString)

            Fire.shared.toggleInputMode()
            return true
        }
        // 监听.flagsChanged事件只为切换中英文，其它情况不处理需要返回 false 以避免快捷键不生效
        // 放行规则：先把 Shift / CapsLock 这类不属于"快捷键修饰键"的位剔除，再要求剩余位
        //   - 为空(无修饰键，如 a、,、.)，或
        //   - 恰好是 .numericPad|.function (方向键、用于翻页)
        // 其它情况（含 Cmd/Ctrl/Option/单独 .function 的 F 键、单独 .numericPad 的数字小键盘等）
        // 全部交给系统处理，避免无谓的 handler 链空跑(predictorHandler 会读 client 的 IPC 状态)。
        // Shift / CapsLock 必须放行的原因：
        //   - Shift+标点是常规中文标点输入路径(Shift+1=! 等)，需要继续走到 punctuationKeyHandler 完成全角转换
        //   - Shift+字母由 charKeyHandler 处理(commit 0b51393 起，大写字母会被附加到原码而不直接上屏)
        // .deviceIndependentFlagsMask 用来过滤低位"设备相关"标志，避免极少数键盘场景下的脏数据误判。
        // 关联 issue #149 #152，回归源 commit 2d66064。
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.shift, .capsLock])
        if event.type == .flagsChanged || (
            !modifiers.isEmpty
            && modifiers != .init(arrayLiteral: .numericPad, .function)
        ) {
            NSLog("[FireInputController] flagChangedHandler no need handle")
            return false
        }
        return nil
    }

    private func enModeHandler(event: NSEvent) -> Bool? {
        NSLog("[FireInputController] enModeHandler")
        // 英文输入模式, 不做任何处理
        if inputMode == .enUS {
            return false
        }
        return nil
    }

    private func predictorHandler(event: NSEvent) -> Bool? {
        // 在数字后输入。号自动转换为小数点
        if Defaults[.enableDotAfterNumber] && event.keyCode == kVK_ANSI_Period && _lastInputIsNumber {
            insertText(".")
            _lastInputIsNumber = false
            return true
        }
        // 在数字后输入“：”，自动转为英文半角冒号
        if Defaults[.enableColonAfterNumber] && event.keyCode == kVK_ANSI_Semicolon && _lastInputIsNumber {
            insertText(":")
            _lastInputIsNumber = false
            return true
        }
        _lastInputIsNumber = false
        
        _lastInputText = getPreviousText()
#if DEBUG
        NSLog("[FireInputController] predictorHandler range, selectionRange: \(selectionRange()), replacementRange: \(replacementRange()), client.selectedRange: \(client().selectedRange()), client.markedRange: \(client().markedRange())")
        NSLog("[FireInputController] predictorHandler previous text, \(_lastInputText)")
#endif

        return nil
    }

    private func pageKeyHandler(event: NSEvent) -> Bool? {
        let keyCode = event.keyCode
        if inputMode == .zhhans && _originalString.count > 0 {
            // 翻页
            let needNextPage = keyCode == kVK_ANSI_Equal ||
                (keyCode == kVK_DownArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_RightArrow && Defaults[.candidatesDirection] == .vertical)
            if needNextPage {
                nextPage()
                return true
            }

            let needPrevPage = keyCode == kVK_ANSI_Minus ||
                (keyCode == kVK_UpArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_LeftArrow && Defaults[.candidatesDirection] == .vertical)
            if needPrevPage {
                prevPage()
                return true
            }

            // 移动高亮
            let isForward = (keyCode == kVK_RightArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_DownArrow && Defaults[.candidatesDirection] == .vertical)
            let isBackward = (keyCode == kVK_LeftArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_UpArrow && Defaults[.candidatesDirection] == .vertical)

            if isForward || isBackward {
                let count = _candidates.count
                if isForward {
                    if selectedIndex < count - 1 {
                        selectedIndex += 1
                        CandidatesWindow.shared.setSelectedIndex(selectedIndex)
                    } else if _hasNext {
                        nextPage()
                    }
                } else {
                    if selectedIndex > 0 {
                        selectedIndex -= 1
                        CandidatesWindow.shared.setSelectedIndex(selectedIndex)
                    } else if curPage > 1 {
                        prevPage()
                    }
                }
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
        guard let string = event.characters else { return nil }

        // 使用预编译的 static let 正则匹配，避免每次按键创建 NSRegularExpression 实例
        let match = Self.letterRegex.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.utf16.count)
        )

        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  _originalString.count <= 0 && match == nil {
            NSLog("非字符,不做处理")
            return nil
        }
        // 当前输入的是英文字符,附加到之前
        if match != nil {
            // 第五码顶字上屏：五笔方案下，当已有≥4码时，先上屏首选词，再以当前键开始新编码
            if Defaults[.wubiFifthCommit],
               Defaults[.codeMode] == .wubi,
               _originalString.count >= 4,
               let firstCandidate = _candidates.first,
               firstCandidate.type != .placeholder {
                insertCandidate(firstCandidate, confirmed: false)
                // insertCandidate → insertText → clean() 已清空 _originalString
                // 第五码作为下个编码的首码
                _originalString = string
                return true
            }

            _originalString += string

            return true
        }
        return nil
    }

    private func numberKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        guard let string = event.characters else { return nil }
        // 当前输入的是数字,选择当前候选列表中的第N个字符 v
        if let pos = Int(string) {
            if _originalString.count > 0 {
                let index = pos - 1
                if index >= 0 && index < _candidates.count {
                    insertCandidate(_candidates[index], confirmed: true)
                } else {
                    _originalString += string
                }
                return true
            }
            _lastInputIsNumber = true
            if Defaults[.enableWhitespaceBetweenZhEn] && Utils.shared.shouldConcatWithWhitespace(_lastInputText, string) {
                // 中文后输入了数字，先插入一个空格
                insertText(" ")
            }
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

    private func isTempEnModeActive() -> Bool {
        !Defaults[.disableTempEnMode]
            && !_originalString.isEmpty
            && _originalString.first == DictManager.shared.tempEnTriggerPunctuation
    }

    private func enterKeyHandler(event: NSEvent) -> Bool? {
        // 回车键输入原字符
        if event.keyCode == kVK_Return && _originalString.count > 0 {
            if isTempEnModeActive(), let first = _candidates.first {
                insertCandidate(first)
            } else {
                insertText(_originalString)
            }
            return true
        }
        return nil
    }

    private func spaceKeyHandler(event: NSEvent) -> Bool? {
        // 空格键输入转换后的中文字符
        if event.keyCode == kVK_Space && _originalString.count > 0 {
            if selectedIndex < _candidates.count {
                insertCandidate(_candidates[selectedIndex], confirmed: true)
            }
            return true
        }
        return nil
    }

    private func extraCandidateKeyHandler(event: NSEvent) -> Bool? {
        guard inputMode == .zhhans,
              _originalString.count > 0,
              !isTempEnModeActive(),
              let string = event.characters else {
            return nil
        }

        let mode = Defaults[.extraCandidateSelectKeys]
        guard mode != .disabled else { return nil }

        let index: Int?
        switch mode {
        case .semicolonQuote:
            switch string {
            case ";": index = 1
            case "'": index = 2
            default: index = nil
            }
        case .commaPeriod:
            switch string {
            case ",": index = 1
            case ".": index = 2
            default: index = nil
            }
        case .disabled:
            index = nil
        }

        guard let index = index, index < _candidates.count else {
            return nil
        }

        insertCandidate(_candidates[index], confirmed: true)
        return true
    }

    private func punctuationKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        guard let string = event.characters else { return nil }
        guard inputMode == .zhhans else { return nil }

        // 判断是否进入或继续临时英文模式
        if shouldStartOrContinueTempEnMode(string: string) {
            _originalString += string
            return true
        }

        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if inputMode == .zhhans, let result = PunctuationConversion.shared.conversion(string) {
            if _originalString.count > 0,
               !isTempEnModeActive(),
               let first = _candidates.first,
               first.type != .placeholder {
                insertCandidate(first)
                insertText(result)
            } else {
                insertText(result)
            }
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
        guard let event = event else { return false }
        NSLog("[FireInputController] handle: \(event.debugDescription)")

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

        let handler = Utils.shared.processHandlers(handlers: [
            deleteConfirmHandler,
            combineHandler,
            hotkeyHandler,
            flagChangedHandler,
            enModeHandler,
            predictorHandler,
            pageKeyHandler,
            deleteKeyHandler,
            charKeyHandler,
            numberKeyHandler,
            escKeyHandler,
            enterKeyHandler,
            spaceKeyHandler,
            extraCandidateKeyHandler,
            punctuationKeyHandler
        ])
        // autoreleasepool 包裹整个事件处理，确保临时对象（NSString、NSAttributedString 等）
        // 在当前 RunLoop 迭代结束前及时释放，避免连续输入时内存峰值持续增长
        return autoreleasepool { () -> Bool in
            handler(event) ?? false
        }
    }

    func updateCandidates(_ sender: Any!) {
        let (candidates, hasNext) = Fire.shared.getCandidates(origin: self._originalString, page: curPage)
        _candidates = candidates
        _hasNext = hasNext
    }

    // 更新候选窗口
    // 逻辑顺序：获取候选 → 满4码唯一候选自动上屏 → 无候选且不显示输入码时关闭窗口 → 显示候选窗
    func refreshCandidatesWindow() {
        updateCandidates(client())
        if Defaults[.wubiAutoCommit] && curPage == 1 && _candidates.count == 1 && _originalString.count >= 4,
           let candidate = _candidates.first, candidate.type != .placeholder {
            // 满4码唯一候选词自动上屏
            insertCandidate(candidate, confirmed: false)
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
            topLeft: getOriginPoint(),
            selectedIndex: selectedIndex
        )
    }

    override func selectionRange() -> NSRange {
        NSLog("[FireInputController] selectionRange")
        if _combineCount != nil {
            // 组词模式下为 1 长度的占位合成串，与 markCombineText 保持一致
            return NSRange(location: 0, length: 1)
        }
        if Defaults[.showCodeInWindow] {
            return NSRange(location: 0, length: min(1, _originalString.count))
        }
        return NSRange(location: 0, length: _originalString.count)
    }

    func insertCandidate(_ candidate: Candidate, confirmed: Bool = false) {
        Fire.shared.lastCommittedText = candidate.text
        // 记录中文候选词上屏，供"快速加词"组词使用
        if candidate.type != .placeholder, candidate.text.contains(where: { $0.isChineseChar }) {
            Fire.shared.recentCommittedTexts.append(candidate.text)
            if Fire.shared.recentCommittedTexts.count > 20 {
                Fire.shared.recentCommittedTexts.removeFirst()
            }
        }

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
        NSLog("insertText: %@", text)
        if text.count > 0 {
            var newText = text
            if Defaults[.enableWhitespaceBetweenZhEn] && Utils.shared.shouldConcatWithWhitespace(_lastInputText, text) {
                newText = " " + newText
                NSLog("[FireInputController] insertCandidate should append whitespace: \(newText)")
            }
            let value = NSAttributedString(string: newText)
            client()?.insertText(value, replacementRange: replacementRange())
            _lastInputIsNumber = newText.last?.isWholeNumber ?? false
            if PunctuationConversion.shared.isPair(newText) {
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
        NSLog("[FireInputController] moveCursor \(client.attributedSubstring(from: NSMakeRange(0, 10))) \(offset), selectedRange: \(client.selectedRange()), markedRange: \(client.markedRange()), length: \(client.length())")
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

    /// 判断是否进入或继续临时英文（temp en）模式
    /// 触发条件：空输入时按 ; 键进入，已在 temp en 时后续字符继续
    private func shouldStartOrContinueTempEnMode(string: String) -> Bool {
        let isTriggerKey = string == String(DictManager.shared.tempEnTriggerPunctuation)
        // 已在临时英文模式：继续追加字符
        if _originalString.first == DictManager.shared.tempEnTriggerPunctuation, !isTriggerKey {
            return true
        }
        // 空输入时按触发键：进入临时英文模式
        return !Defaults[.disableTempEnMode] && _originalString.isEmpty && isTriggerKey
    }

    func clean() {
        NSLog("[FireInputController] clean")
        _originalString = ""
        curPage = 1
        _pendingDeleteCandidate = nil
        _combineCount = nil
        CandidatesWindow.shared.close()
    }
}

extension Character {
    // 是否为 CJK 统一表意文字(常用汉字区)
    var isChineseChar: Bool {
        unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }
}
