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
        NSLog("terminate runing")
//        let running = NSRunningApplication.runningApplications(withBundleIdentifier: NSRunningApplication.current.bundleIdentifier!).first
//        if (running != nil && NSRunningApplication.current != running) {
//            running?.forceTerminate()
//        }
        fire = Fire.shared
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("lanched")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

