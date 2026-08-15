//
//  QuickCombineState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//
import Carbon
import AppKit

struct QuickCombineState: InputState {
    private var count: Int = 2
    
    let dict: any EngineDictManager
    
    var store: any EngineStore
    
    init(count: Int = 2, dict: some EngineDictManager, store: some EngineStore) {
        self.count = count
        self.dict = dict
        self.store = store
    }
    
    func updateContext(_ context: inout any InputContext) {
        let text = combineText(self.count)
        // 五笔码显示在候选窗原码区；code 与 origin 保持一致以避免出现多余的"()"
        let code = dict.queryWubiCode(text) ?? "无法取码"
        let tip = Candidate(
            code: code,
            text: "",
            type: .placeholder,
            label: "【\(text)】，←键增字， →键减字，Enter键确认， Esc键取消"
        )
        context.candidates = [tip]
        context.origin = code
        context.hasNext = false
    }
    
    func didEnter(_ context: inout any InputContext) {
        updateContext(&context)
    }
    
    func combineText(_ count: Int) -> String {
        return store.recentCommittedTexts.suffix(count).joined()
    }
    
    private func confirmCombine(_ context: inout any InputContext) {
        let text = combineText(self.count)
        if let code = dict.queryWubiCode(text) {
            // 如果该词已被屏蔽，取消屏蔽后继续添加为用户词
            if self.dict.isBlocked(text) {
                self.dict.unblockText(text)
            }
            self.dict.addUserText(origin: code, text: text)
            // 组词成功时显示编码提示，方便用户验证
            context.showMessage("已添加新词【\(text)】\(code)")
        } else {
            context.showMessage("无法为【\(text)】生成五笔码")
        }
    }

    mutating func handle(_ event: KeyInput, context: inout any InputContext) -> HandleResult {
        let bufCount = store.recentCommittedTexts.count
        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            self.count = min(count + 1, bufCount)
            updateContext(&context)
            return .stay(true)
        case kVK_RightArrow:
            self.count = max(count - 1, 2)
            updateContext(&context)
            return .stay(true)
        case kVK_Return:
            confirmCombine(&context)
            return .exit(true)
        case kVK_Escape:
            return .exit(true)
        default:
            return .stay(true)
        }
    }
    
    func willExit(_ context: inout any InputContext) {
        context.origin = ""
        context.candidates = []
        context.curPage = 1
        context.hasNext = false
    }
}
