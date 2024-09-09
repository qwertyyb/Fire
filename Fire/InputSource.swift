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
    let kSourceID = Bundle.main.bundleIdentifier!
    var selected: Bool? = nil

    func registerInputSource() {
        if !isEnabled() {
            // 全新安装或未启用过，需要Register, 已启用的，不需要再次启用
            let installedLocationURL = NSURL(fileURLWithPath: installLocation)
            let err = TISRegisterInputSource(installedLocationURL as CFURL)
            NSLog("register input source: \(err)")
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
            let selectable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable)
            ).takeUnretainedValue())
            let enableable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnableCapable)
            ).takeUnretainedValue())
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
            NSLog("select input source: \(err)")
            let isSelected = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(
                TISGetInputSourceProperty(result, kTISPropertyInputSourceIsSelected)
            ).takeUnretainedValue())
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
            TISGetInputSourceProperty(result, kTISPropertyInputSourceIsEnabled)
        ).takeUnretainedValue())
        if !enabled {
            let err = TISEnableInputSource(result)
            NSLog("Enabled input source: \(err)")
        }
    }

    func deactivateInputSource() {
        guard let source = findInputSource() else {
            return
        }
        TISDeselectInputSource(source)
        TISDisableInputSource(source)
        NSLog("Disable input source")
    }

    func onSelectChanged(callback: @escaping (Bool) -> Void) -> NSObjectProtocol {
        NSLog("[InputSource] onSelectChanged")
        let observer = DistributedNotificationCenter.default()
            .addObserver(
                forName: .init(String(kTISNotifySelectedKeyboardInputSourceChanged)),
                 object: nil,
                 queue: nil,
                 using: { _ in
                     // 这个回调发现两个问题
                     // 1. 在当前输入法是 ABC 英文输入法时，在应用启动后第一次切换到当前输入法时，此回调不会调用，此问题暂时无法处理
                     // 2. 在此回调中直接获取当前输入法是否被选择，可能不准确（状态尚未更新），需要 asyncAfter 0.1s 后再获取状态
                     // 3. 此事件有可能会被重复调用，比如切换到搜狗输入法时，所以事件需要过滤一下
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                         let selected = self.isSelected()
                         NSLog("[InputSource] onSelectChanged callback: \(String(describing: self.selected)), \(selected)")
                         // 此事件会重复触发，此处判断需要过滤一下
                         if (selected != self.selected) {
                             self.selected = selected
                             callback(self.selected!)
                         }
                     }
                }
            )
        return observer
    }

    func isSelected() -> Bool {
        guard let result = findInputSource(forUsage: .selected) else {
            return false
        }
        let unsafeIsSelected = TISGetInputSourceProperty(
            result,
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
            result,
            kTISPropertyInputSourceIsEnabled
        ).assumingMemoryBound(to: CFBoolean.self)
        let isEnabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(unsafeIsEnabled).takeUnretainedValue())

        return isEnabled
    }

    static let shared = InputSource()
}
