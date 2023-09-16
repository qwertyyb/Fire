//
//  FirePreferencesController.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Settings
import AppKit

class FirePreferencesController: NSObject, NSWindowDelegate {
    private var controller: SettingsWindowController?
    static let shared = FirePreferencesController()

    var isVisible: Bool {
        controller?.window?.isVisible ?? false
    }

    private func initController() {
        if let controller = controller {
            controller.show()
            return
        }
        self.controller = SettingsWindowController(
            panes: [
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "基本"),
                     title: "基本",
                    toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!
                ) {
                    GeneralPane()
                },
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "标点符号"),
                     title: "标点符号",
                    toolbarIcon: NSImage(named: NSImage.fontPanelName) ?? NSImage(named: "general")!
                ) {
                    PunctuationPane()
                },
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "用户词库"),
                     title: "用户词库",
                    toolbarIcon: NSImage(named: NSImage.multipleDocumentsName) ?? NSImage(named: "general")!
                ) {
                    UserDictPane()
                },
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "应用"),
                     title: "应用",
                    toolbarIcon: NSImage(named: NSImage.computerName) ?? NSImage(named: "general")!
                ) {
                    ApplicationPane()
                },
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "主题"),
                     title: "主题",
                    toolbarIcon: NSImage(named: NSImage.colorPanelName) ?? NSImage(named: "general")!
                ) {
                    ThemePane()
                },
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "统计"),
                     title: "统计",
                    toolbarIcon: NSImage(named: NSImage.bonjourName) ?? NSImage(named: "general")!
                ) {
                    StatisticsPane()
                },
                Settings.Pane(
                    identifier: Settings.PaneIdentifier(rawValue: "高级"),
                     title: "高级",
                    toolbarIcon: NSImage(named: NSImage.advancedName)!
                ) {
                    ThesaurusPane()
                }
            ],
            style: .toolbarItems
        )
        self.controller?.window?.delegate = self
    }

    func showPane(_ name: String) {
        initController()
        controller?.show(pane: Settings.PaneIdentifier(rawValue: name))
    }

    func show() {
        initController()
        controller?.show()
    }
}
