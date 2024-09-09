//
//  Fire.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import AppKit
import Defaults
import InputMethodKit
import Sparkle

let kConnectionName = "Fire_1_Connection"

class Fire: NSObject {
    // 逻辑
    static let candidateInserted = Notification.Name("Fire.candidateInserted")
    static let inputModeChanged = Notification.Name("Fire.inputModeChanged")

    var inputMode: InputMode = .zhhans

    override init() {
        super.init()
        _ = InputSource.shared.onSelectChanged { selected in
            NSLog("[Fire] onSelectChanged: \(selected)")
            if selected {
                // 如果从其他输入法切换至当前输入法，则把当前输入法的输入模式设置为中文
                // 此处有一个点需要关注：此回调和 activateServer 的调用顺序没有明确的结论，所以这里设置的状态有可能会被 activateServer 中的 activeCurrentClientInputMode 重写，这不太符合预期。目前在实际的使用过程中发现是 activateServer 先调用，暂时符合预期，需要观察一下实际使用过程中的情况
                self.toggleInputMode(.zhhans)
            }
            StatusBar.shared.refresh()
        }
    }

    func toggleInputMode(_ nextInputMode: InputMode? = nil, showTip: Bool = true) {
        if nextInputMode != nil, self.inputMode == nextInputMode {
            return
        }
        let oldVal = self.inputMode
        if let nextInputMode = nextInputMode, nextInputMode != self.inputMode {
            self.inputMode = nextInputMode
        } else {
            self.inputMode = inputMode == .enUS ? .zhhans : .enUS
        }
        if showTip {
            toastCurrentMode()
        }
        StatusBar.shared.refresh()
        NotificationCenter.default.post(name: Fire.inputModeChanged, object: nil, userInfo: [
            "oldVal": oldVal,
            "val": self.inputMode,
            "label": self.inputMode == .enUS ? "英" : "中"
        ])
    }

    func toastCurrentMode() {
        let text = inputMode == .enUS ? "英" : "中"

        // 针对当前界面没有输入框，或者有输入框，但是有可能导致提示窗超出屏幕无法显示的场景，不显示提示窗
        let position = CandidatesWindow.shared.inputController?.getOriginPoint() ?? NSPoint.zero

        let isVisible = NSScreen.screens.contains { screen in
            let frame = screen.frame
            return frame.minX < position.x && position.x < frame.maxX
                && frame.minY < position.y && position.y < frame.maxY
        }

        if !isVisible {
            return
        }

        Utils.shared.toast?.show(text, position: position)
    }

    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    func getCandidates(origin: String = String(), page: Int = 1) -> (candidates: [Candidate], hasNext: Bool) {
        if origin.count <= 0 {
            return ([], false)
        }
        let (candidates, hasNext) = DictManager.shared.getCandidates(query: origin, page: page)
        let transformed = candidates.map { (candidate) -> Candidate in
            if candidate.type == .user {
                return Candidate(code: candidate.code, text: candidate.text, type: .user)
            }
            return candidate
        }
        return (transformed, hasNext)
    }

    static let shared = Fire()
}
