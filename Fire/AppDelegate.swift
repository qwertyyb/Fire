//
//  AppDelegate.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let fire: Fire
    override init() {
        fire = Fire.shared
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
//        server = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
//        var candidate = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType:kIMKMain)
//        let identifier = Bundle.main.bundleIdentifier;
//        server = IMKServer.init(name: kConnectionName, bundleIdentifier: identifier)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

