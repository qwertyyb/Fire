//
//  menu.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import AppKit
import Sparkle

extension FireInputController {
    /* -- menu actions start -- */
    @objc func openAbout (_ sender: Any!) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(sender)
    }
    @objc func checkForUpdates(_ sender: Any!) {
        NSApp.setActivationPolicy(.accessory)
        SUUpdater.shared()?.checkForUpdates(sender)
    }
    override func showPreferences(_ sender: Any!) {
        NSApp.setActivationPolicy(.accessory)
        FirePreferencesController.shared.show()
    }
    @objc func showUserDictPrefs(_ sender: Any!) {
        NSApp.setActivationPolicy(.accessory)
        FirePreferencesController.shared.showPane("用户词库")
    }
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.items = [
            NSMenuItem(title: "首选项", action: #selector(showPreferences(_:)), keyEquivalent: ""),
            NSMenuItem(title: "用户词库", action: #selector(showUserDictPrefs(_:)), keyEquivalent: ""),
            NSMenuItem(title: "检查更新", action: #selector(checkForUpdates(_:)), keyEquivalent: ""),
            NSMenuItem(title: "关于业火输入法", action: #selector(openAbout(_:)), keyEquivalent: "")
        ]
        return menu
    }
}
