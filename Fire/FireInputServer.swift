//
//  FireInputServer.swift
//  Fire
//
//  Created by marchyang on 2022/7/13.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import Defaults

extension FireInputController {
    /**
    * 根据当前输入的应用改变输入模式
    */
    private func restoreCurrentClientInputMode() -> Bool {
        let currentMode = Fire.shared.inputMode
        guard let identifier = client()?.bundleIdentifier() else { return false }
        if let appSetting = Defaults[.appSettings][identifier],
         let mode = InputMode(rawValue: appSetting.inputModeSetting.rawValue) {
            NSLog("[FireInputController] restoreClientInputMode from setting : \(identifier), \(mode)")
            Fire.shared.toggleInputMode(mode, showTip: false)
            return currentMode != Fire.shared.inputMode
        }
        // 启用APP缓存设置
        if Defaults[.keepAppInputMode], let mode = InputModeCache.shared.get(identifier) {
            NSLog("[FireInputController] restoreClientInputMode from cache: \(identifier), \(mode)")
            Fire.shared.toggleInputMode(mode, showTip: false)
            return currentMode != Fire.shared.inputMode
        }
        return false
    }

    private func savePreviousClientInputMode() {
        if Defaults[.keepAppInputMode],
           let controller = CandidatesWindow.shared.inputController,
           let identifier = controller.client()?.bundleIdentifier(),
           Defaults[.appSettings][identifier] == nil {
            NSLog("[Fire] saveClientInputMode \(identifier), \(inputMode)")
            // 缓存当前输入模式
            InputModeCache.shared.put(identifier, inputMode)
        }
    }

    override func activateServer(_ sender: Any!) {
        NSLog("[FireInputController] activate server: \(client()?.bundleIdentifier() ?? sender.debugDescription)")
        
        // 这个保存动作之所以不在 deactivateServer 中做，主要是因为 activateServer 和 deactivateServer 的调用顺序不固定
        // 而 inputMode 是全局的，如果是 activateServer 先调用，则会写入 inputMode
        // 在后调用 deactivateServer 中保存 inputMode 时，保存的已经不是之前的 inputMode 了
        savePreviousClientInputMode()

        CandidatesWindow.shared.inputController = self

        if Defaults[.disableEnMode] {
            return
        }

        let changed = restoreCurrentClientInputMode()

        if changed && Defaults[.appInputModeTipShowTime] != .none || Defaults[.appInputModeTipShowTime] == .always {
            // 在 MacOS 15.1 上当切换应用时，如果目标应用没有输入框聚焦，直接调用 toastCurrentMode 会卡顿 3 秒左右
            // 经过验证在 async 中调用才不会卡顿
            DispatchQueue.main.async {
                Fire.shared.toastCurrentMode()
            }
        }
    }
    override func deactivateServer(_ sender: Any!) {
        insertOriginText()
        clean()
//        saveClientInputMode()
        NSLog("[FireInputController] deactivate server: \(client()?.bundleIdentifier() ?? "no client deactivate")")
    }
}
