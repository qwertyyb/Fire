//
//  AppDelegate.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit
import Defaults

extension Defaults.Keys {
    static let wubiCodeTip = Key<Bool>("wubiCodeTip", default: true)
    static let wubiAutoCommit = Key<Bool>("wubiAutoCommit", default: false)
    static let candidateCount = Key<Int>("candidateCount", default: 5)
    static let codeMode = Key<CodeMode>("codeMode", default: CodeMode.wubiPinyin)
    //            ^            ^         ^                ^
    //           Key          Type   UserDefaults name   Default value
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let fire: Fire
    override init() {
        fire = Fire.shared
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if CommandLine.arguments.count > 1 {
            print("[Fire] launch argument: \(CommandLine.arguments[1])")
            if CommandLine.arguments[1] == "--install" {
                print("install input source")
                registerInputSource()
                deactivateInputSource()
                activateInputSource()
                NSApp.terminate(nil)
                return
            }
        }
        NSLog("launch input source")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
