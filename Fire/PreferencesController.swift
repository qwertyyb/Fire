//
//  PreferencesController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/30.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa

class PreferencesController: NSWindowController {

    @IBOutlet weak var WubiButton: NSButton!
    @IBOutlet weak var PinyinButton: NSButton!
    @IBOutlet weak var WubiPinyinButton: NSButton!
    override func windowDidLoad() {
        super.windowDidLoad()
        print("window load")
        let mode = UserDefaults.standard.integer(forKey: "codeMode")
        
        if mode == 0 {
            WubiButton.state = .on
        } else if mode == 1 {
            PinyinButton.state = .on
        } else {
            WubiPinyinButton.state = .on
        }
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
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
