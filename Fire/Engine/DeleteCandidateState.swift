//
//  DeleteCandidateState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//
import Carbon

struct DeleteCandidateState: InputState {
    // control+shift+数字，删除选词
    static func shouldEnter(_ event: KeyInput, context: any InputContext) -> Bool {
        if event.modifiers == [.control, .shift],
           let deleteIndex = Self.digitByKeyCode[event.keyCode],
           deleteIndex <= context.candidates.count && deleteIndex > 0,
           context.candidates[deleteIndex - 1].type != .placeholder {
            return true
        }
        return false
    }
    
    static var digitByKeyCode: [UInt16: Int] = [
        UInt16(kVK_ANSI_1): 1, UInt16(kVK_ANSI_2): 2, UInt16(kVK_ANSI_3): 3,
        UInt16(kVK_ANSI_4): 4, UInt16(kVK_ANSI_5): 5, UInt16(kVK_ANSI_6): 6,
        UInt16(kVK_ANSI_7): 7, UInt16(kVK_ANSI_8): 8, UInt16(kVK_ANSI_9): 9
    ]
    
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
        Utils.shared.showMessage("已删除「\(target.text)」")
    }
    
    mutating func handle(_ event: KeyInput, context: inout any InputContext, exitState: () -> Void) -> Bool? {
        // 回车确认删除
        if event.keyCode == kVK_Return {
            deleteCandidate(self.candidate)
            exitState()
            return true
        }
        if EngineUtils.isEscapeKey(event) {
            exitState()
            return true
        }
        return true
    }
    
    func willExit(_ context: inout any InputContext) {
        context.curPage = self.prevCurPage
        context.selectedIndex = self.prevSelectedIndex
    }
    
}
