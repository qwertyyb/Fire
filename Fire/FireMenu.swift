//
//  menu.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Sparkle

extension FireInputController {
    /* -- menu actions start -- */
    @objc func openAbout (_ sender: Any!) {
        NSApp.setActivationPolicy(.regular)
        NSApp.orderFrontStandardAboutPanel(sender)
    }
    @objc func checkForUpdates(_ sender: Any!) {
        NSApp.setActivationPolicy(.regular)
        SUUpdater.shared()?.checkForUpdates(sender)
    }
    override func showPreferences(_ sender: Any!) {
        NSApp.setActivationPolicy(.regular)
        FirePreferencesController.shared.controller.show()
    }
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.items = [
            NSMenuItem(title: "关于业火输入法", action: #selector(openAbout(_:)), keyEquivalent: ""),
            NSMenuItem(title: "检查更新", action: #selector(checkForUpdates(_:)), keyEquivalent: ""),
            NSMenuItem(title: "首选项", action: #selector(showPreferences(_:)), keyEquivalent: "")
        ]
        return menu
    }
}
