//
//  DeleteCandidateState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//
import Carbon

struct DeleteCandidateState: InputState {
    // 修饰键+数字，删除选词
    static func shouldEnter(_ event: KeyInput, context: any InputContext, shortcut: DigitInputShortcut) -> Bool {
        if shortcut.matches(event),
           let deleteIndex = InputShortcut.digitByKeyCode[event.keyCode],
           deleteIndex <= context.candidates.count && deleteIndex > 0,
           context.candidates[deleteIndex - 1].type != .placeholder {
            return true
        }
        return false
    }
    
    private let candidate: Candidate
    private var prevCurPage: Int = 1
    private var prevSelectedIndex = 0
    
    let dict: any EngineDictManager
    
    init(candidate: Candidate, dict: some EngineDictManager) {
        self.candidate = candidate
        self.dict = dict
    }
    
    mutating func didEnter(_ context: inout any InputContext) {
        // 把进入此状态前的状态保存下来，在退出时恢复
        self.prevCurPage = context.curPage
        self.prevSelectedIndex = context.selectedIndex
        
        context.candidates = [
            Candidate(
                code: context.origin,  // code 设为原码，避免 getShownCode 显示多余的"()"
                text: "",               // text 置空，防止鼠标点按候选时误插入文字
                type: .placeholder,
                label: "确认删除「\(self.candidate.text)」? Enter键确认， Esc键取消"
            )
        ]
        context.curPage = 1
        context.hasNext = false
        context.selectedIndex = 0
    }

    private func deleteCandidate(_ target: Candidate) {
        FireLog.input.debug("confirmDelete: \(target.text)")
        self.dict.blockCandidate(target)
    }
    
    mutating func handle(_ event: KeyInput, context: inout any InputContext) -> HandleResult {
        // 回车确认删除
        if event.keyCode == kVK_Return {
            deleteCandidate(self.candidate)
            context.showMessage("已删除「\(self.candidate.text)」")
            return .exit(true)
        }
        if EngineUtils.isEscapeKey(event) {
            return .exit(true)
        }
        return .stay(true)
    }
    
    func willExit(_ context: inout any InputContext) {
        context.curPage = self.prevCurPage
        context.selectedIndex = self.prevSelectedIndex
    }
    
}
