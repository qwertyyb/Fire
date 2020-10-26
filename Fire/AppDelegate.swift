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

    var fire: Fire!

    func installInputSource() {
        print("install input source")
        InputSource.shared.registerInputSource()
        InputSource.shared.activateInputSource()
        NSApp.terminate(nil)
    }
    
    private func commandHandler() {
        if CommandLine.arguments.count > 1 {
            print("[Fire] launch argument: \(CommandLine.arguments[1])")
            let command = CommandLine.arguments[1]
            if command == "--install" {
                return installInputSource()
            }
            if command == "--build-dict" {
                print("[Fire] build dict")
                buildDict()
                return NSApp.terminate(nil)
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        commandHandler()
        if !hasDict() {
            NSLog("[Fire] first run，build dict")
            buildDict()
        }
        NSLog("[Fire] app is running")
        fire = Fire.shared
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
