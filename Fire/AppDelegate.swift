//
//  AppDelegate.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import AppKit
import InputMethodKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static var fire: Fire = .init()
    static var statistics: Statistics = .init()
    static var statusBar: StatusBar = .init()

    func installInputSource() {
        print("install input source")
        InputSource.shared.registerInputSource()
        InputSource.shared.activateInputSource()
        InputSource.shared.selectInputSource { _ in
            NSApp.terminate(self)
        }
    }

    func stop() {
        InputSource.shared.deactivateInputSource()
        NSApp.terminate(nil)
    }

    private func commandHandler() -> Bool {
        if CommandLine.arguments.count > 1 {
            print("[Fire] launch argument: \(CommandLine.arguments[1])")
            let command = CommandLine.arguments[1]
            if command == "--install" {
                installInputSource()
                return false
            }
            if command == "--build-dict" {
                print("[Fire] build dict")
                buildDict()
                NSApp.terminate(nil)
                return false
            }
            if command == "--stop" {
                print("[Fire] stop")
                stop()
                return false
            }
        }
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !commandHandler() {
            return
        }
        if !hasDict() {
            NSLog("[Fire] first run，build dict")
            buildDict()
        }
        NSLog("[Fire] app is running")
        Self.fire = Fire.shared
        Self.statistics = Statistics.shared
        Self.statusBar = StatusBar.shared
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
