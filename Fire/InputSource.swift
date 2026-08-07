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
    let kSourceID = Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire"
    var selected: Bool? = nil

    /// 从 TISInputSource 属性中读取 CFBoolean 值
    /// 将重复的 Unmanaged<CFBoolean>.fromOpaque / takeUnretainedValue / CFBooleanGetValue 模式集中处理
    private func getBoolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
    }

    func registerInputSource() {
        if !isEnabled() {
            // 全新安装或未启用过，需要Register, 已启用的，不需要再次启用
            let installedLocationURL = NSURL(fileURLWithPath: installLocation)
            let err = TISRegisterInputSource(installedLocationURL as CFURL)
            FireLog.app.error("register input source: \(err, privacy: .public)")
        }
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
            let err = TISSelectInputSource(result)
            FireLog.app.error("select input source: \(err, privacy: .public)")
            let isSelected = self.getBoolProperty(result, kTISPropertyInputSourceIsSelected)
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
        let enabled = getBoolProperty(result, kTISPropertyInputSourceIsEnabled)
        if !enabled {
            let err = TISEnableInputSource(result)
            FireLog.app.error("Enabled input source: \(err, privacy: .public)")
        }
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
        let unsafeIsEnabled = TISGetInputSourceProperty(
            result,
            kTISPropertyInputSourceIsEnabled
        ).assumingMemoryBound(to: CFBoolean.self)
        let isEnabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(unsafeIsEnabled).takeUnretainedValue())

        return isEnabled
    }

    static let shared = InputSource()
}
