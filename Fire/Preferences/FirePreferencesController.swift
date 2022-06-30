//
//  FirePreferencesController.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Preferences

class FirePreferencesController: NSObject, NSWindowDelegate {
    private var controller: PreferencesWindowController?
    static let shared = FirePreferencesController()

    var isVisible: Bool {
        controller?.window?.isVisible ?? false
    }

    func show() {
        if let controller = controller {
            controller.show()
            return
        }
        self.controller = PreferencesWindowController(
            panes: [
                Preferences.Pane(
                    identifier: Preferences.PaneIdentifier(rawValue: "基本"),
                     title: "基本",
                    toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!
                ) {
                    GeneralPane()
                },
                Preferences.Pane(
                    identifier: Preferences.PaneIdentifier(rawValue: "标点符号"),
                     title: "标点符号",
                    toolbarIcon: NSImage(named: NSImage.fontPanelName) ?? NSImage(named: "general")!
                ) {
                    PunctutionPane()
                },
                Preferences.Pane(
                    identifier: Preferences.PaneIdentifier(rawValue: "应用"),
                     title: "应用",
                    toolbarIcon: NSImage(named: NSImage.computerName) ?? NSImage(named: "general")!
                ) {
                    ApplicationPane()
                },
                Preferences.Pane(
                    identifier: Preferences.PaneIdentifier(rawValue: "主题"),
                     title: "主题",
                    toolbarIcon: NSImage(named: NSImage.colorPanelName) ?? NSImage(named: "general")!
                ) {
                    ThemePane()
                },
                Preferences.Pane(
                    identifier: Preferences.PaneIdentifier(rawValue: "统计"),
                     title: "统计",
                    toolbarIcon: NSImage(named: NSImage.bonjourName) ?? NSImage(named: "general")!
                ) {
                    StatisticsPane()
                },
                Preferences.Pane(
                    identifier: Preferences.PaneIdentifier(rawValue: "高级"),
                     title: "高级",
                    toolbarIcon: NSImage(named: NSImage.advancedName)!
                ) {
                    ThesaurusPane()
                }
            ],
            style: .toolbarItems
        )
        self.controller?.window?.delegate = self
        self.controller?.show()
    }
}
