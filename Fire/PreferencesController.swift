//
//  PreferencesController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/30.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa

class PreferencesController: NSWindowController {

    @IBOutlet weak var wubiButton: NSButton!
    @IBOutlet weak var pinyinButton: NSButton!
    @IBOutlet weak var wubiPinyinButton: NSButton!
    override func windowDidLoad() {
        super.windowDidLoad()
        print("window load")
        let mode = UserDefaults.standard.integer(forKey: "codeMode")

        if mode == 0 {
            wubiButton.state = .on
        } else if mode == 1 {
            pinyinButton.state = .on
        } else {
            wubiPinyinButton.state = .on
        }
    }
    @IBAction func codeModeChange(_ sender: NSButton) {
        let curMode = sender.tag
        print(curMode)
        UserDefaults.standard.set(curMode, forKey: "codeMode")
    }
    @IBAction func openWindow(_ sender: NSMenuItem) {
        super.showWindow(sender)
        print("show window")
        self.window?.orderFront(sender)
    }
}
