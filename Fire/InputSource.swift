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
    let bundleID = Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire"
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

    private func findInputSource(forUsage: InputSourceUsage = .enable, all: Bool = false)
        -> TISInputSource? {
        let conditions = NSMutableDictionary()
        conditions.setValue(kSourceID, forKey: kTISPropertyInputSourceID as String)
        guard let sourceList = TISCreateInputSourceList(conditions, all)?.takeRetainedValue() as? [TISInputSource] else {
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
        if all == false {
            return findInputSource(forUsage: forUsage, all: true)
        }
        return nil
    }

    // enable 会拉起系统设置，并弹窗确认是否启用此输入法，用户点击确认启用后就可以选中此输入法
    func enableInputSource() -> Bool {
        let conditions = NSMutableDictionary()
        conditions.setValue(bundleID, forKey: kTISPropertyInputSourceID as String)
        guard let sourceList = TISCreateInputSourceList(conditions, true)?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }
        sourceList.forEach({ source in
            let capable = source.value(forProperty: kTISPropertyInputSourceIsEnableCapable, type: Bool.self) ?? false
            // 坑：TISEnableInputSource之后，kTISPropertyInputSourceIsEnabled的值在当前进程不会更新
            let enabled = source.value(forProperty: kTISPropertyInputSourceIsEnabled, type: Bool.self) ?? false
            // 如果已经 enabled，就不要再enable，会导致重复弹窗
            if capable && !enabled {
                let err = TISEnableInputSource(source)
                FireLog.app.info("enable input source: \(err, privacy: .public)")
            }
        })
        return true
    }

    // select 会选中此输入法，需要注意的是，必须先 enable 输入法添加到候选列表，才能选中
    func selectInputSource() -> Bool {
        guard let source = findInputSource(forUsage: .selected) else {
            return false
        }
        if getBoolProperty(source, kTISPropertyInputSourceIsSelected) {
            return true
        }
        let err = TISSelectInputSource(source)
        FireLog.app.info("select input source: \(err, privacy: .public)")
        if err == noErr || getBoolProperty(source, kTISPropertyInputSourceIsSelected) {
            return true
        }
        return false
    }
    
    func ensureSelectInputSource(timeout: TimeInterval = 30, interval: TimeInterval = 0.2) -> Bool {
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
        let enabled = getBoolProperty(result, kTISPropertyInputSourceIsEnabled)
        return enabled
    }

    static let shared = InputSource()
}
