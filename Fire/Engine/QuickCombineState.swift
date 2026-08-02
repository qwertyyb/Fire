//
//  QuickCombineState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//
import Carbon
import AppKit

struct QuickCombineState: InputState {
    // control+= 快速组词
    static let shortcutModifier: NSEvent.ModifierFlags = .control
    static let shortcutKeyCode = kVK_ANSI_Equal
    
    private var count: Int = 2
    
    init(count: Int = 2) {
        self.count = 2
    }
    
    func updateContext(_ context: inout any InputContext) {
        let text = combineText(self.count)
        // 五笔码显示在候选窗原码区；code 与 origin 保持一致以避免出现多余的"()"
        let code = DictManager.shared.queryWubiCode(text) ?? "无法取码"
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
        return Fire.shared.recentCommittedTexts.suffix(count).joined()
    }
    
    private func confirmCombine() {
        let text = combineText(self.count)
        if let code = DictManager.shared.queryWubiCode(text) {
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
    }

    mutating func handle(_ event: KeyInput, context: inout any InputContext, exitState: () -> Void) -> Bool? {
        let bufCount = Fire.shared.recentCommittedTexts.count
        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            self.count = min(count + 1, bufCount)
            updateContext(&context)
            return true
        case kVK_RightArrow:
            self.count = max(count - 1, 2)
            updateContext(&context)
            return true
        case kVK_Return:
            confirmCombine()
            exitState()
            return true
        case kVK_Escape:
            exitState()
            return true
        default:
            return true
        }
    }
    
    func willExit(_ context: inout any InputContext) {
        context.origin = ""
        context.candidates = []
        context.curPage = 1
        context.hasNext = false
    }
}
