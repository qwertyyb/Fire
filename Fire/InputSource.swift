//
//  InputSource.swift
//  Fire
//
//  Created by marchyang on 2020/10/19.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Carbon

class InputSource {
    let installLocation = "/Library/Input Methods/Fire.app"
    let kSourceID = "com.qwertyyb.inputmethod.Fire"
    let kInputModeID = "com.qwertyyb.inputmethod.Fire"

    func registerInputSource() {
        let installedLocationURL = NSURL(fileURLWithPath: installLocation)
        TISRegisterInputSource(installedLocationURL as CFURL)
        NSLog("register input source")
    }

    private func transformTargetSource(_ inputSource: TISInputSource)
        -> (inputSource: TISInputSource, sourceID: NSString)? {
        let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
        let sourceID = Unmanaged<CFString>.fromOpaque(ptr!).takeUnretainedValue() as NSString
        if (sourceID.isEqual(to: kSourceID) ) || sourceID.isEqual(to: kInputModeID) {
            return (inputSource, sourceID)
        }
        return nil
    }

    private func findInputSource() -> (inputSource: TISInputSource, sourceID: NSString)? {
        let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue()

        for index in 0...CFArrayGetCount(sourceList)-1 {
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(CFArrayGetValueAtIndex(
                sourceList, index)).takeUnretainedValue()
            if let result = transformTargetSource(inputSource) {
                return result
            }
        }
        return nil
    }

    func activateInputSource() {
        guard let result = findInputSource() else {
            return
        }
        TISEnableInputSource(result.inputSource)
        NSLog("Enabled input source: %@", result.sourceID)
        let isSelectable = Unmanaged<CFBoolean>.fromOpaque(
            TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsSelectCapable)
        ).takeUnretainedValue()
        if CFBooleanGetValue(isSelectable) {
            TISSelectInputSource(result.inputSource)
            NSLog("Selected input source: %@", result.sourceID)
        }
    }

    func deactivateInputSource() {
        guard let source = findInputSource() else {
            return
        }
        TISDisableInputSource(source.inputSource)
        NSLog("Disable input source: %@", source.sourceID)
    }

    func isSelected() -> Bool {
        guard let result = findInputSource() else {
            return false
        }
        let unsafeIsSelected = TISGetInputSourceProperty(
            result.inputSource,
            kTISPropertyInputSourceIsSelected
        ).assumingMemoryBound(to: CFBoolean.self)
        let isSelected = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(unsafeIsSelected).takeUnretainedValue())

        return isSelected
    }

    static let shared = InputSource()
}
