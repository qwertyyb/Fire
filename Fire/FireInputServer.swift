//
//  FireInputServer.swift
//  Fire
//
//  Created by marchyang on 2022/7/13.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import Defaults

private var inputModeCache: [String: InputMode] = [:]

extension FireInputController {
    /**
    * 根据当前输入的应用改变输入模式
    */
    private func activeCurrentClientInputMode() -> Bool {
        let currentMode = Fire.shared.inputMode
        guard let identifier = client()?.bundleIdentifier() else { return false }
        if let appSetting = Defaults[.appSettings][identifier],
         let mode = InputMode(rawValue: appSetting.inputModeSetting.rawValue) {
            NSLog("[FireInputController] activeClientInputMode from setting : \(identifier), \(mode)")
            Fire.shared.toggleInputMode(mode, showTip: false)
            return currentMode != Fire.shared.inputMode
        }
        // 启用APP缓存设置
        if Defaults[.keepAppInputMode], let mode = inputModeCache[identifier] {
            NSLog("[FireInputController] activeClientInputMode from cache: \(identifier), \(mode)")
            Fire.shared.toggleInputMode(mode, showTip: false)
            return currentMode != Fire.shared.inputMode
        }
        return false
    }

    private func savePreviousClientInputMode() {
        if let identifier = CandidatesWindow.shared.inputController?.client()?.bundleIdentifier() {
            // 缓存当前输入模式
            inputModeCache.updateValue(inputMode, forKey: identifier)
        }
    }

    func previousClientHandler() {
        clean()
        savePreviousClientInputMode()
    }

    override func activateServer(_ sender: Any!) {
        NSLog("[FireInputController] activate server: \(client()?.bundleIdentifier() ?? sender.debugDescription)")

        previousClientHandler()

        CandidatesWindow.shared.inputController = self

        if Defaults[.disableEnMode] {
            return
        }

        let changed = activeCurrentClientInputMode()

        if changed && Defaults[.appInputModeTipShowTime] != .none || Defaults[.appInputModeTipShowTime] == .always {
            Fire.shared.toastCurrentMode()
        }
    }
    override func deactivateServer(_ sender: Any!) {
        clean()
        NSLog("[FireInputController] deactivate server: \(client()?.bundleIdentifier() ?? "no client deactivate")")
    }
}
