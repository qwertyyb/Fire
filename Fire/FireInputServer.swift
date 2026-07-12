//
//  FireInputServer.swift
//  Fire
//
//  Created by marchyang on 2022/7/13.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import Carbon
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

        if IsSecureEventInputEnabled() {
            /** 安全事件输入模式指输入密码的场景
             * 一般情况下系统会自动切换到 ABC 输入法，在输入过程中不会调用第三方输入法
             * 但在删除系统 ABC 输入法的情况下，仍然有可能会调用到第三方输入法 https://github.com/qwertyyb/Fire/issues/158
             * 在这种情况下，输入法需要切换到英文模式，避免影响用户输入密码
             */
            Fire.shared.toggleInputMode(.enUS, showTip: Fire.shared.inputMode != .enUS)
            return
        }

        if Defaults[.disableEnMode] {
            // 由于 disableEnMode 为 true，所以需要切换到中文模式
            Fire.shared.toggleInputMode(.zhhans, showTip: Fire.shared.inputMode != .zhhans)
            return
        }

        let changed = restoreCurrentClientInputMode()

        if (changed && Defaults[.appInputModeTipShowTime] != .none) || Defaults[.appInputModeTipShowTime] == .always {
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
        // 跨会话重置标点配对状态（引号/括号计数归零），
        // 避免切换 App 后延续上一次会话的配对状态，导致开闭颠倒
        PunctuationConversion.shared.reset()
//        saveClientInputMode()
        NSLog("[FireInputController] deactivate server: \(client()?.bundleIdentifier() ?? "no client deactivate")")
    }
}
