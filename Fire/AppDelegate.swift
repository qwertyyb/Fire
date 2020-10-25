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

enum CandidatesDirection: Int, Decodable, Encodable {
    case vertical
    case horizontal
}

extension Defaults.Keys {
    static let candidatesDirection = Key<CandidatesDirection>(
        "candidatesDirection",
        default: CandidatesDirection.horizontal
    )
    static let showCodeInWindow = Key<Bool>("showCodeInWindow", default: true)
    static let wubiCodeTip = Key<Bool>("wubiCodeTip", default: true)
    static let wubiAutoCommit = Key<Bool>("wubiAutoCommit", default: false)
    static let candidateCount = Key<Int>("candidateCount", default: 5)
    static let codeMode = Key<CodeMode>("codeMode", default: CodeMode.wubiPinyin)
    //            ^            ^         ^                ^
    //           Key          Type   UserDefaults name   Default value
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var fire: Fire!

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
            if CommandLine.arguments[1] == "--build-dict" {
                buildDict()
                NSApp.terminate(nil)
                return
            }
        }
//        buildDict()
        NSLog("app is running")
        fire = Fire.shared
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
