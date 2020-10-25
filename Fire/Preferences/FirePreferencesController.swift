//
//  FirePreferencesController.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Preferences

class FirePreferencesController {
    lazy var controller = PreferencesWindowController(
        panes: [
            Preferences.Pane(
                identifier: Preferences.PaneIdentifier(rawValue: "基本"),
                 title: "基本",
                toolbarIcon: NSImage(named: "general")!
            ) {
                GeneralPane()
            },
            Preferences.Pane(
                identifier: Preferences.PaneIdentifier(rawValue: "高级"),
                 title: "高级",
                toolbarIcon: NSImage(named: "advanced")!
            ) {
                ThesaurusPane()
            }
        ]
    )
    static let shared = FirePreferencesController()
}
