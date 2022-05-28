//
//  InputSource.swift
//  Fire
//
//  Created by marchyang on 2020/10/19.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Carbon
import AppKit

enum InputSourceUsage {
    case enable
    case selected
}

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

    private func findInputSource(forUsage: InputSourceUsage = .enable) -> (inputSource: TISInputSource, sourceID: NSString)? {
        let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue()

        for index in 0...CFArrayGetCount(sourceList)-1 {
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(CFArrayGetValueAtIndex(
                sourceList, index)).takeUnretainedValue()
            if let result = transformTargetSource(inputSource) {
                let selectable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                    TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsSelectCapable)
                ).takeUnretainedValue())
                let enableable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                    TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsEnableCapable)
                ).takeUnretainedValue())
                NSLog("find input source: %@, enableable: \(enableable), selectable: \(selectable)", result.sourceID)
                if forUsage == .enable && enableable {
                    return result
                }
                if forUsage == .selected && selectable {
                    return result
                }
                if selectable {
                    return result
                }
            }
        }
        return nil
    }

    func selectInputSource() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard let result = self.findInputSource(forUsage: .selected) else {
                return
            }
            TISSelectInputSource(result.inputSource)
            let isSelected = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsSelected)
            ).takeUnretainedValue())
            NSLog("Selected input source: %@, selected: \(isSelected)", result.sourceID)
            if isSelected {
                timer.invalidate()
                NSApp.terminate(nil)
            }
        }
    }

    func activateInputSource() {
        guard let result = findInputSource() else {
            return
        }
        let enabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
            TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsEnabled)
        ).takeUnretainedValue())
        if !enabled {
            TISEnableInputSource(result.inputSource)
            NSLog("Enabled input source: %@", result.sourceID)
        }
        selectInputSource()
    }

    func deactivateInputSource() {
        guard let source = findInputSource() else {
            return
        }
        TISDeselectInputSource(source.inputSource)
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
