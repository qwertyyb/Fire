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

extension TISInputSource {
    func value<T>(forProperty propertyKey: CFString, type: T.Type) -> T? {
        guard let value = TISGetInputSourceProperty(self, propertyKey) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue() as? T
    }
}

class InputSource {
    static let selectChanged = Notification.Name("InputSource.selectChanged")
    
    let installLocation = "/Library/Input Methods/Fire.app"
    let kSourceID = (Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire") + ".Hans"
    var selected: Bool? = nil

    /// 从 TISInputSource 属性中读取 CFBoolean 值
    /// 将重复的 Unmanaged<CFBoolean>.fromOpaque / takeUnretainedValue / CFBooleanGetValue 模式集中处理
    private func getBoolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
    }

    @discardableResult
    func registerInputSource() -> Bool {
        if isEnabled() {
            return true
        }
        let installedLocationURL = NSURL(fileURLWithPath: installLocation)
        let err = TISRegisterInputSource(installedLocationURL as CFURL)
        FireLog.app.info("register input source: \(err, privacy: .public)")
        return err == noErr
    }

    private func findInputSource(forUsage: InputSourceUsage = .enable)
        -> TISInputSource? {
        let conditions = NSMutableDictionary()
        conditions.setValue(kSourceID, forKey: kTISPropertyInputSourceID as String)
        guard let sourceList = TISCreateInputSourceList(conditions, true)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        for index in 0..<sourceList.count {
            let inputSource = sourceList[index]
            let selectable = getBoolProperty(inputSource, kTISPropertyInputSourceIsSelectCapable)
            let enableable = getBoolProperty(inputSource, kTISPropertyInputSourceIsEnableCapable)
            if forUsage == .enable && enableable {
                return inputSource
            }
            if forUsage == .selected && selectable {
                return inputSource
            }
            if selectable {
                return inputSource
            }
        }
        return nil
    }

    func enableInputSource(timeout: TimeInterval = 30, interval: TimeInterval = 0.2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let source = findInputSource(forUsage: .enable) else {
                Thread.sleep(forTimeInterval: interval)
                continue
            }
            if getBoolProperty(source, kTISPropertyInputSourceIsEnabled) {
                return true
            }
            let err = TISEnableInputSource(source)
            FireLog.app.info("enable input source: \(err, privacy: .public)")
            if err == noErr {
                return true
            }
            Thread.sleep(forTimeInterval: interval)
        }
        return false
    }

    func selectInputSource(timeout: TimeInterval = 30, interval: TimeInterval = 0.2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let source = findInputSource(forUsage: .selected) else {
                Thread.sleep(forTimeInterval: interval)
                continue
            }
            if !getBoolProperty(source, kTISPropertyInputSourceIsEnabled) {
                TISEnableInputSource(source)
            }
            if !getBoolProperty(source, kTISPropertyInputSourceIsSelected) {
                let err = TISSelectInputSource(source)
                FireLog.app.info("select input source: \(err, privacy: .public)")
            }
            if getBoolProperty(source, kTISPropertyInputSourceIsSelected) {
                return true
            }
            Thread.sleep(forTimeInterval: interval)
        }
        return false
    }

    func deactivateInputSource() {
        guard let source = findInputSource() else {
            return
        }
        TISDeselectInputSource(source)
        TISDisableInputSource(source)
        FireLog.app.info("Disable input source")
    }

    func startSelectChangedMonitor() {
        FireLog.app.debug("onSelectChanged")
        DistributedNotificationCenter.default()
            .addObserver(self,
                         selector: #selector(selectedKeyboardInputSourceChanged),
                         name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                         object: nil,
                         suspensionBehavior: .deliverImmediately)
    }
    
    @objc func selectedKeyboardInputSourceChanged() {
        let selected = self.isSelected()
        if selected != self.selected {
            self.selected = selected
            NotificationCenter.default.post(
                name: Self.selectChanged,
                object: nil,
                userInfo: [
                    "selected": selected
                ])
        }
    }

    func isSelected() -> Bool {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let id = source.value(forProperty: kTISPropertyInputSourceID, type: String.self)
        return id != nil && id == kSourceID
    }

    func isEnabled() -> Bool {
        guard let result = findInputSource(forUsage: .enable) else {
            return false
        }
        return getBoolProperty(result, kTISPropertyInputSourceIsEnabled)
    }

    static let shared = InputSource()
}
