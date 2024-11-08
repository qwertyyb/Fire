//
//  CLI.swift
//  Fire
//
//  Created by 杨永榜 on 2024/9/12.
//

import AppKit
import Foundation
import Combine

class FireCLI {
    static let getModeNotificationName = Notification.Name("FireCLI.getMode")
    static let setModeNotificationName = Notification.Name("FireCLI.setMode")
    
    static let replyNotificationName = Notification.Name("FireCLI.reply")

    func getMode() {
        DistributedNotificationCenter.default().postNotificationName(FireCLI.getModeNotificationName, object: nil, deliverImmediately: true)
    }
    func setMode(_ mode: String, showTip: Bool = true) {
        DistributedNotificationCenter.default().postNotificationName(FireCLI.setModeNotificationName, object: nil, userInfo: ["mode" : mode, "showTip": showTip], deliverImmediately: true)
    }
    
    var replySubscribe: AnyCancellable? = nil
    init() {
        replySubscribe = DistributedNotificationCenter.default().publisher(for: FireCLI.replyNotificationName).sink(receiveValue: { notification in
            guard let result = notification.userInfo?["result"] as? String else {
                self.exit()
                return
            }
            print(result)
            self.exit()
        })
    }
    
    func exit() {
        replySubscribe?.cancel()
        NSApp.terminate(nil)
    }

    deinit {
        self.exit()
    }
}
