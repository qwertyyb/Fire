//
//  RootState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//
import Carbon
import Defaults

class RootState: InputState {
    func didEnter(_ context: inout any InputContext) {
        
    }
    
    func willExit(_ context: inout any InputContext) {
        
    }
    
    private static let letterRegex = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
    
    var subState: (any InputState)?
    
    func setSubState(_ subState: (any InputState)?, context: inout any InputContext) {
        self.subState?.willExit(&context)
        self.subState = subState
        self.subState?.didEnter(&context)
    }

    // MARK: - 子状态
    // 处理子状态
    private func subStateHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        guard var subState = self.subState else { return nil }
        var shouldExitSubState = false
        let result = subState.handle(event, context: &context, exitState: {
            shouldExitSubState = true
        })
        self.subState = subState
        if shouldExitSubState {
            setSubState(nil, context: &context)
        }
        return result
    }
    
    // 是否进入子状态处理：临时英文、删除候选词、快速组词
    private func enterTempEnHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        if (TempEnState.shouldEnter(event, context: context)) {
            setSubState(TempEnState(), context: &context)
            return true
        }
        return nil
    }
    
    private func enterDeleteCandidateHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        if (DeleteCandidateState.shouldEnter(event, context: context)) {
            let targetIndex = (DeleteCandidateState.digitByKeyCode[event.keyCode] ?? 1) - 1
            setSubState(DeleteCandidateState(candidate: context.candidates[targetIndex]), context: &context)
            return true
        }
        return nil
    }
    
    private func enterQuickCombineHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        if event.modifiers == .control, event.keyCode == UInt16(kVK_ANSI_Equal), context.origin.isEmpty {
            if Fire.shared.recentCommittedTexts.count >= 2 {
                setSubState(QuickCombineState(count: 2), context: &context)
            } else {
                Utils.shared.showMessage("请先输入至少两个字，再按 control+= 组词")
            }
            return true
        }
        return nil
    }
    
    // MARK: - 简单处理不再单独为英文输入模式开一个状态

    func flagsChangeHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        FireLog.input.debug("flagChangedHandler")
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if !Defaults[.disableEnMode] && EngineUtils.toggleInputModeKeyUpChecker.check(event) {
            let inputMode = context.inputMode
            FireLog.input.info("toggle mode: \(String(describing: inputMode), privacy: .public)")

            // 把当前未上屏的原始code上屏处理
            context.commit(context.origin)
            setSubState(nil, context: &context)

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
        //   - Shift+标点是常规中文标点输入路径(Shift+1=! 等)，需要继续走到 postCodingEngineHandler 的标点决策完成全角转换
        //   - Shift+字母由 charKeyHandler 处理(commit 0b51393 起，大写字母会被附加到原码而不直接上屏)
        // .deviceIndependentFlagsMask 用来过滤低位"设备相关"标志，避免极少数键盘场景下的脏数据误判。
        // 关联 issue #149 #152，回归源 commit 2d66064。
        let modifiers = event.modifiers
            .subtracting([.shift, .capsLock])
        if event.type == .flagsChanged || (
            !modifiers.isEmpty
            && modifiers != .init(arrayLiteral: .numericPad, .function)
        ) {
            FireLog.input.debug("flagChangedHandler no need handle")
            return false
        }
        return nil
    }
    
    private func enModeHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        FireLog.input.debug("enModeHandler")
        // 英文输入模式, 不做任何处理
        if context.inputMode == .enUS {
            return false
        }
        return nil
    }
    
    // MARK: - 中文输入模式下的按键处理: 翻页键、删除键、字符键、数字键、esc键、enter键、space键
    private func hotkeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        FireLog.input.debug("hotkeyHandler")
        guard let chars = event.charactersIgnoringModifiers, let num = Int(chars) else {
            return nil
        }
        // Ctrl+Option+数字：置顶候选词
        if event.modifiers == [.control, .option] &&
            num > 0 && num <= context.candidates.count {
            FireLog.input.debug("hotkey: control + option + \(num)")
            DictManager.shared.setCandidateToFirst(query: context.origin, candidate: context.candidates[num-1])
            context.curPage = 1
            context.selectedIndex = 0
            return true
        }
        return nil
    }
    
    private func pageKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        let keyCode = event.keyCode
        if context.inputMode == .zhhans && context.origin.count > 0 {
            // 翻页
            let shouldNextPage = keyCode == kVK_ANSI_Equal ||
                (keyCode == kVK_DownArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_RightArrow && Defaults[.candidatesDirection] == .vertical)
            if shouldNextPage {
                context.nextPage()
                return true
            }

            let needPrevPage = keyCode == kVK_ANSI_Minus ||
                (keyCode == kVK_UpArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_LeftArrow && Defaults[.candidatesDirection] == .vertical)
            if needPrevPage {
                context.prevPage()
                return true
            }

            // 移动高亮
            let isForward = (keyCode == kVK_RightArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_DownArrow && Defaults[.candidatesDirection] == .vertical)
            let isBackward = (keyCode == kVK_LeftArrow && Defaults[.candidatesDirection] == .horizontal) ||
                (keyCode == kVK_UpArrow && Defaults[.candidatesDirection] == .vertical)

            if isForward || isBackward {
                let count = context.candidates.count
                if isForward {
                    if context.selectedIndex < count - 1 {
                        context.selectedIndex += 1
                    } else if context.hasNext {
                        context.nextPage()
                        context.selectedIndex = 0
                    }
                } else {
                    if context.selectedIndex > 0 {
                        context.selectedIndex -= 1
                    } else if context.curPage > 1 {
                        context.curPage -= 1
                        // 方向键到头回绕：高亮定位到上一页的最后一个候选词
                        context.selectedIndex = Defaults[.candidateCount] - 1
                    }
                }
                return true
            }
        }
        return nil
    }
    
    private func predictorHandler(event: KeyInput, context: inout any InputContext) -> Bool? {
        // 在数字后输入。号自动转换为小数点
        let textBefore = context.getTextBefore(1)
        if textBefore.isEmpty || Int(textBefore) == nil {
            return nil
        }
        
        if Defaults[.enableDotAfterNumber] && event.keyCode == kVK_ANSI_Period {
            context.commit(".")
            return true
        }
        // 在数字后输入“：”，自动转为英文半角冒号
        if Defaults[.enableColonAfterNumber] && event.keyCode == kVK_ANSI_Semicolon {
            context.commit(":")
            return true
        }

        return nil
    }

    private func deleteKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        FireLog.input.debug("deleteKeyHandler: \(EngineUtils.isDeleteKey(event))")
        // 删除键删除字符
        if EngineUtils.isDeleteKey(event) {
            if context.origin.count > 0 {
                context.origin = String(context.origin.dropLast())
                context.curPage = 1
                context.selectedIndex = 0
                return true
            }
            return false
        }
        return nil
    }
    
    private func charKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        // 获取输入的字符
        guard let string = event.characters else { return nil }

        // 使用预编译的 static let 正则匹配，避免每次按键创建 NSRegularExpression 实例
        let match = Self.letterRegex.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.utf16.count)
        )

        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  context.origin.isEmpty && match == nil {
            FireLog.input.debug("非字符,不做处理")
            return nil
        }
        // 当前输入的是英文字符,附加到之前
        if match != nil {
            // 第五码顶字上屏：五笔方案下，当已有≥4码时，先上屏首选词，再以当前键开始新编码
            if Defaults[.wubiFifthCommit],
               Defaults[.codeMode] == .wubi,
               context.origin.count >= 4,
               let firstCandidate = context.candidates.first,
               firstCandidate.type != .placeholder {
                context.commitCandidate(firstCandidate, confirmed: false)
                // insertCandidate → insertText → clean() 已清空 _originalString
                // 第五码作为下个编码的首码
                context.origin = string
                context.curPage = 1
                context.selectedIndex = 0
                return true
            }

            context.origin += string
            context.curPage = 1
            context.selectedIndex = 0

            return true
        }
        return nil
    }

    private func numberKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        // 获取输入的字符
        guard let char = event.characters else { return nil }
        // 当前输入的是数字,选择当前候选列表中的第N个字符 v
        if let pos = Int(char) {
            if context.origin.count > 0 {
                let index = pos - 1
                if index >= 0 && index < context.candidates.count {
                    context.commitCandidate(context.candidates[index], confirmed: true)
                } else {
                    context.origin += char
                    context.curPage = 1
                    context.selectedIndex = 0
                }
                return true
            }
            // 原码为空，输入数字，为了让中英文之间的空白配置生效，此处不要交给系统处理
            context.commit(char)
            return true
        }
        return nil
    }
    
    private func extraCandidateKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        guard context.inputMode == .zhhans,
              context.origin.count > 0,
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

        guard let index = index, index < context.candidates.count else {
            return nil
        }

        context.commitCandidate(context.candidates[index], confirmed: true)
        return true
    }

    private func escKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        // ESC键取消所有输入
        if EngineUtils.isEscapeKey(event), context.origin.count > 0 {
            context.origin = ""
            context.candidates = []
            context.curPage = 1
            context.selectedIndex = 0
            return true
        }
        return nil
    }
    
    private func enterKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        // 回车键输入原字符
        if event.keyCode == kVK_Return && context.origin.count > 0 {
            context.commit(context.origin)
            return true
        }
        return nil
    }

    private func spaceKeyHandler(_ event: KeyInput, context: inout any InputContext) -> Bool? {
        FireLog.input.debug("spaceKeyHandler")
        if event.keyCode == kVK_Space && context.candidates.count > 0 {
            if context.selectedIndex < context.candidates.count {
                context.commitCandidate(context.candidates[context.selectedIndex], confirmed: true)
            }
            return true
        }
        return nil
    }
    
    static func punctuationKeyHandler(event: KeyInput, context: inout any InputContext) -> Bool? {
        // 获取输入的字符
        guard let string = event.characters else { return nil }
        guard context.inputMode == .zhhans else { return nil }

        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if let result = PunctuationConversion.shared.conversion(string) {
            if let first = context.candidates.first,
               first.type != .placeholder {
                // 首个候选自动上屏
                context.commitCandidate(first, confirmed: false)
            }
            context.commit(result)
            return true
        }
        return nil
    }
    
    func handle(_ event: KeyInput, context: inout any InputContext, exitState: () -> Void) -> Bool? {
        let codingHandlers = [
            subStateHandler,
            
            enterTempEnHandler,
            enterDeleteCandidateHandler,
            enterQuickCombineHandler,
            
            flagsChangeHandler,
            enModeHandler,
            
            hotkeyHandler,
            pageKeyHandler,
            predictorHandler,
            deleteKeyHandler,
            charKeyHandler,
            numberKeyHandler,
            extraCandidateKeyHandler,
            escKeyHandler,
            enterKeyHandler,
            spaceKeyHandler,
            Self.punctuationKeyHandler, // 需要放在 extraCandidateKeyHandler 后面
        ]
        for handler in codingHandlers {
            if let result = handler(event, &context) {
                if subState == nil {
                    if context.origin.isEmpty {
                        context.candidates = []
                        context.origin = ""
                    } else {
                        let (candidates, hasNext) = Fire.shared.getCandidates(origin: context.origin, page: context.curPage)
                        context.candidates = candidates
                        context.hasNext = hasNext
                    }
                }
                return result
            }
        }
        return nil
    }
}
