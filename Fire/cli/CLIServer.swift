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
        getModSubscribe = DistributedNotificationCenter.default().publisher(for: FireCLI.getModeNotificationName).sink { notification in
            self.reply(Fire.shared.inputMode.rawValue)
        }
        setModSubscribe = DistributedNotificationCenter.default().publisher(for: FireCLI.setModeNotificationName).sink { notification in
            guard let mode = notification.userInfo?["mode"] as? String else {
                self.reply(nil)
                return
            }
            guard let inputMode = InputMode(rawValue: mode) else {
                self.reply(nil)
                return
            }
            let showTip = notification.userInfo?["showTip"] as? Bool
            Fire.shared.toggleInputMode(inputMode, showTip: showTip ?? true)
            self.reply(nil)
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
