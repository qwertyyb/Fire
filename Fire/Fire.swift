//
//  Fire.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import AppKit
import InputMethodKit
import Sparkle
import Combine
import Defaults

let kConnectionName = "Fire_1_Connection"

class Fire: NSObject {
    // 逻辑
    static let candidateInserted = Notification.Name("Fire.candidateInserted")
    static let engine = Engine.shared

    // 当前激活的输入控制器，供候选窗鼠标点击等场景使用
    weak var activeInputController: FireInputController?
    var cancellables: [AnyCancellable] = []
    let modifierKeyPressChecker: ModifierKeyPressChecker

    override init() {
        modifierKeyPressChecker = ModifierKeyPressChecker(modifierKey: Defaults[.toggleInputModeKey]) { modifierKey in
            Self.engine.toggleInputMode()
        }
        super.init()
        _ = InputSource.shared.onSelectChanged { selected in
            FireLog.app.info("onSelectChanged: \(selected, privacy: .public)")
            if selected {
                // 如果从其他输入法切换至当前输入法，则把当前输入法的输入模式设置为中文
                // 此处有一个点需要关注：此回调和 activateServer 的调用顺序没有明确的结论，所以这里设置的状态有可能会被 activateServer 中的 activeCurrentClientInputMode 重写，这不太符合预期。目前在实际的使用过程中发现是 activateServer 先调用，暂时符合预期，需要观察一下实际使用过程中的情况
                Self.engine.toggleInputMode(.zhhans)
            }
            StatusBar.shared.refresh()
        }
        NotificationCenter.default.publisher(for: Engine.inputModeChanged)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                if notification.userInfo?["val"] as? InputMode == InputMode.enUS {
                    self.activeInputController?.insertOriginText()
                }
                StatusBar.shared.refresh()
                self.toastCurrentMode()
            }
            .store(in: &cancellables)
    }

    func toastCurrentMode() {
        let text = Self.engine.inputMode == .enUS ? "英" : "中"
        FireLog.app.debug("ToastCurrentMode: \(text, privacy: .public)")

        // 针对当前界面没有输入框，或者有输入框，但是有可能导致提示窗超出屏幕无法显示的场景，不显示提示窗
        let position = CandidatesWindow.shared.inputController?.getOriginPoint() ?? NSPoint.zero
        FireLog.app.debug("ToastCurrentMode position: \(String(describing: position), privacy: .public)")

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

    let server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

    static let shared = Fire()
}
