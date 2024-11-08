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

    var fire: Fire!
    var statistics: Statistics!
    var statusBar: StatusBar!
    var cliServer: FireCLIServer!

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
            let command = CommandLine.arguments[1]
            if command == "--install" {
                print("[Fire] launch argument: \(command)")
                installInputSource()
                return false
            }
            if command == "--build-dict" {
                print("[Fire] launch argument: \(command)")
                print("[Fire] build dict")
                buildDict()
                NSApp.terminate(nil)
                return false
            }
            if command == "--stop" {
                print("[Fire] launch argument: \(command)")
                print("[Fire] stop")
                stop()
                return false
            }
            if command == "--get-mode" {
                let cli = FireCLI()
                cli.getMode()
                return false
            }
            if command == "--set-mode" {
                if CommandLine.arguments.count < 2 {
                    print("[Fire] commandHandler: no mode specifiy (enUs/zhhans)")
                }
                let mode = CommandLine.arguments[2]
                let showTip = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] != "false" : true
                let cli = FireCLI()
                cli.setMode(mode, showTip: showTip)
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
        fire = Fire.shared
        statistics = Statistics.shared
        statusBar = StatusBar.shared
        cliServer = FireCLIServer()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
