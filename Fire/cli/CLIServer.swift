//
//  CLIServer.swift
//  Fire
//
//  Created by 杨永榜 on 2024/9/12.
//

import Foundation
import Combine

class FireCLIServer {
    var getModSubscribe: AnyCancellable? = nil
    var setModSubscribe: AnyCancellable? = nil
    init() {
        getModSubscribe = DistributedNotificationCenter.default().publisher(for: FireCLI.getModeNotificationName).sink { _ in
            // 切换主线程执行 UI 相关回调逻辑，避免子线程操作 UI 引发崩溃
            // DispatchQueue 属于 GCD（Grand Central Dispatch）
            // 是苹果底层并发调度框架，隶属于 libdispatch，iOS/macOS 全平台通用。
            DispatchQueue.main.async {
                self.reply(Fire.engine.inputMode.rawValue)
            }
        }
        setModSubscribe = DistributedNotificationCenter.default().publisher(for: FireCLI.setModeNotificationName).sink { notification in
            // 切换主线程执行 UI 相关回调逻辑，避免子线程操作 UI 引发崩溃
            // DispatchQueue 属于 GCD（Grand Central Dispatch）
            // 是苹果底层并发调度框架，隶属于 libdispatch，iOS/macOS 全平台通用。
            DispatchQueue.main.async {
                guard let mode = notification.userInfo?["mode"] as? String,
                      let inputMode = InputMode(rawValue: mode) else {
                    self.reply(nil)
                    return
                }
                let showTip = notification.userInfo?["showTip"] as? Bool
                Fire.engine.toggleInputMode(inputMode)
                self.reply(nil)
            }
        }
    }
    
    func reply(_ result: String?) {
        DistributedNotificationCenter.default().postNotificationName(FireCLI.replyNotificationName, object: nil, userInfo: ["result": result ?? ""], deliverImmediately: true)
    }
    
    deinit {
        getModSubscribe?.cancel()
        setModSubscribe?.cancel()
    }
}
