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
        if !isEnabled() {
            // 全新安装或未启用过，需要Register, 已启用的，不需要再次启用
            let installedLocationURL = NSURL(fileURLWithPath: installLocation)
            TISRegisterInputSource(installedLocationURL as CFURL)
            NSLog("register input source")
        }
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

    private func findInputSource(forUsage: InputSourceUsage = .enable)
        -> (inputSource: TISInputSource, sourceID: NSString)? {
        let sourceList = TISCreateInputSourceList(nil, true).takeRetainedValue() as NSArray

        for index in 0..<sourceList.count {
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(CFArrayGetValueAtIndex(
                sourceList, index)).takeUnretainedValue()
            if let result = transformTargetSource(inputSource) {
                let selectable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                    TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsSelectCapable)
                ).takeUnretainedValue())
                let enableable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                    TISGetInputSourceProperty(result.inputSource, kTISPropertyInputSourceIsEnableCapable)
                ).takeUnretainedValue())
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

    func selectInputSource(callback: @escaping (Bool) -> Void) {
        let maxTryTimes = 30
        var tryTimes = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if tryTimes > maxTryTimes {
                timer.invalidate()
                callback(false)
                return
            }
            tryTimes += 1
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
                callback(true)
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
    }

    func deactivateInputSource() {
        guard let source = findInputSource() else {
            return
        }
        TISDeselectInputSource(source.inputSource)
        TISDisableInputSource(source.inputSource)
        NSLog("Disable input source: %@", source.sourceID)
    }

    func onSelectChanged(callback: @escaping (Bool) -> Void) -> NSObjectProtocol {
        let observer = DistributedNotificationCenter.default()
            .addObserver(
                forName: .init(String(kTISNotifySelectedKeyboardInputSourceChanged)),
                 object: nil,
                 queue: nil,
                 using: { _ in
                    callback(self.isSelected())
                }
            )
        return observer
    }

    func isSelected() -> Bool {
        guard let result = findInputSource(forUsage: .selected) else {
            return false
        }
        let unsafeIsSelected = TISGetInputSourceProperty(
            result.inputSource,
            kTISPropertyInputSourceIsSelected
        ).assumingMemoryBound(to: CFBoolean.self)
        let isSelected = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(unsafeIsSelected).takeUnretainedValue())

        return isSelected
    }

    func isEnabled() -> Bool {
        guard let result = findInputSource(forUsage: .enable) else {
            return false
        }
        let unsafeIsEnabled = TISGetInputSourceProperty(
            result.inputSource,
            kTISPropertyInputSourceIsEnabled
        ).assumingMemoryBound(to: CFBoolean.self)
        let isEnabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(unsafeIsEnabled).takeUnretainedValue())

        return isEnabled
    }

    static let shared = InputSource()
}
