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
import Defaults

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
    @objc func setAppicationMode(_ sender: Any!) {
        if let menuWrapper = sender as? [String: Any],
           let menuItem = menuWrapper["IMKCommandMenuItem"] as? NSMenuItem,
           let dict = menuItem.representedObject as? [String: Any],
           let bundleID = dict["bundleID"] as? String,
           let mode = dict["mode"] as? InputMode {
            NSLog("[FireInputController] setApplicationMode, \(bundleID), \(mode)")
            var appSettings = Defaults[.appSettings]
            appSettings[bundleID] = ApplicationSettingItem(bundleId: bundleID, inputMs: mode == .zhhans ? .zhhans : .enUS)
            Defaults[.appSettings] = appSettings
        }
    }
    override func menu() -> NSMenu! {
        NSLog("[FireInputController] menu")
        let menu = NSMenu()
        menu.items = [
            NSMenuItem(title: "首选项", action: #selector(showPreferences(_:)), keyEquivalent: ""),
            NSMenuItem(title: "用户词库", action: #selector(showUserDictPrefs(_:)), keyEquivalent: ""),
        ]
        if !Defaults[.disableEnMode],
            let controller = CandidatesWindow.shared.inputController,
            let bundleID = controller.client()?.bundleIdentifier() {
            var displayName = bundleID
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                displayName = FileManager.default.displayName(atPath: url.path)
            }
            let title = "设置“\(displayName)”的预设为\(Fire.shared.inputMode == .zhhans ? "中文" : "英文")"
            let menuItem = NSMenuItem(title: title, action: #selector(setAppicationMode(_:)), keyEquivalent: "")
            menuItem.representedObject = [
                "bundleID": bundleID,
                "mode": Fire.shared.inputMode
            ]
            menu.items.append(contentsOf: [
                NSMenuItem.separator(),
                menuItem,
            ])
        }
        menu.items.append(contentsOf: [
            NSMenuItem.separator(),
            NSMenuItem(title: "检查更新", action: #selector(checkForUpdates(_:)), keyEquivalent: ""),
            NSMenuItem(title: "关于业火输入法", action: #selector(openAbout(_:)), keyEquivalent: "")
        ])
        return menu
    }
}
