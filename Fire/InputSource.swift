//
//  InputSource.swift
//  Fire
//
//  Created by marchyang on 2020/10/19.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Carbon

let installLocation = "/Library/Input Methods/Fire.app"
let kSourceID = "com.qwertyyb.inputmethod.Fire"
let kInputModeID = "com.qwertyyb.inputmethod.Fire"

func registerInputSource() {
    let installedLocationURL = CFURLCreateFromFileSystemRepresentation(
        nil,
        installLocation,
        installLocation.count,
        false
    )
    if installedLocationURL != nil {
        TISRegisterInputSource(installedLocationURL)
        NSLog("register input source")
    }
}

func activateInputSource() {
    let sourceList = TISCreateInputSourceList(nil, true)

    for index in 0...CFArrayGetCount(sourceList!.takeUnretainedValue())-1 {
        let inputSource = Unmanaged<TISInputSource>.fromOpaque(CFArrayGetValueAtIndex(
            sourceList?.takeUnretainedValue(), index)).takeUnretainedValue()
        let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
        let sourceID = Unmanaged<CFString>.fromOpaque(ptr!).takeUnretainedValue() as NSString
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
}

func deactivateInputSource() {
    let sourceList = TISCreateInputSourceList(nil, true)

    for index in 0...CFArrayGetCount(sourceList!.takeUnretainedValue())-1 {
        let inputSource = Unmanaged<TISInputSource>.fromOpaque(CFArrayGetValueAtIndex(
            sourceList?.takeUnretainedValue(), index)).takeUnretainedValue()
        let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
        let sourceID = Unmanaged<CFString>.fromOpaque(ptr!).takeUnretainedValue() as NSString
        if (sourceID.isEqual(to: kSourceID) ) || sourceID.isEqual(to: kInputModeID) {
            TISDisableInputSource(inputSource)
            NSLog("Disable input source: %@", sourceID)
      }
    }
}
