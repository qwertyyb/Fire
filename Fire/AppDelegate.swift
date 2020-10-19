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
        let installedLocationURL = CFURLCreateFromFileSystemRepresentation(
            nil,
            "/Library/Input Methods/Fire.app",
            "/Library/Input Methods/Fire.app".count,
            false
        )
        let kSourceID = "com.qwertyyb.inputmethod.Fire"

        let kInputModeID = "com.qwertyyb.inputmethod.Fire"

        if installedLocationURL != nil {
            TISRegisterInputSource(installedLocationURL)
        }

        let sourceList = TISCreateInputSourceList(nil, true)

        for index in 0...CFArrayGetCount(sourceList!.takeUnretainedValue())-1 {
//            sourceList?.takeUnretainedValue()
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(CFArrayGetValueAtIndex(
                sourceList?.takeUnretainedValue(), index)).takeUnretainedValue()
            let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
            let sourceID = Unmanaged<CFString>.fromOpaque(ptr!).takeUnretainedValue() as NSString
//            NSLog("examining input source '%@", sourceID);
            if (sourceID.isEqual(to: kSourceID) ) || sourceID.isEqual(to: kInputModeID) {
                TISEnableInputSource(inputSource)
                NSLog("Enabled input source: %@", sourceID)
                let isSelectable = Unmanaged<CFBoolean>.fromOpaque(TISGetInputSourceProperty(
                    inputSource, kTISPropertyInputSourceIsSelectCapable)).takeUnretainedValue()
                if CFBooleanGetValue(isSelectable) {
                  TISSelectInputSource(inputSource)
                  NSLog("Selected input source: %@", sourceID)
                }
          }
        }
        NSLog("lanched")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
