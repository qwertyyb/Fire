//
//  StatusBar.swift
//  Fire
//
//  Created by 虚幻 on 2022/6/3.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import AppKit
import Carbon
import Combine
import Defaults

class StatusBar {
    static let shared = StatusBar()

    let statusItem: NSStatusItem
    private var inputSourceChangedSubscription: AnyCancellable?
    private var inputModeChangedSubscription: AnyCancellable?
    private var showInputModeStatusSubscript: AnyCancellable?
    private init() {
        // 输入法变化时，根据当前选中状态切换显示
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "中"
        statusItem.button?.action = #selector(changeInputMode)
        statusItem.button?.target = self

        refreshVisibleStatus()

        startEventsListener()

        showInputModeStatusSubscript = Defaults.publisher(.showInputModeStatus).sink { event in
            if event.newValue {
                self.startEventsListener()
            } else {
                self.stopEventListener()
            }
            self.refreshVisibleStatus()
        }
    }

    deinit {
        stopEventListener()
        showInputModeStatusSubscript?.cancel()
        showInputModeStatusSubscript = nil
    }

    private func startEventsListener() {
        stopEventListener()
        inputSourceChangedSubscription = DistributedNotificationCenter.default()
            .publisher(for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))
            .sink { _ in
                self.statusItem.isVisible = InputSource.shared.isSelected()
            }

        // inputMode变化时，刷新标题
        inputModeChangedSubscription = NotificationCenter.default.publisher(for: Fire.inputModeChanged)
            .sink { _ in
                self.refreshTitle()
            }
    }
    
    private func stopEventListener() {
        inputSourceChangedSubscription?.cancel()
        inputModeChangedSubscription?.cancel()
        inputModeChangedSubscription = nil
        inputSourceChangedSubscription = nil
    }

    @objc func changeInputMode() {
        Fire.shared.toggleInputMode()
    }

    private func refreshTitle() {
        statusItem.button?.title = Fire.shared.inputMode == .zhhans ? "中" : "英"
    }

    private func refreshVisibleStatus() {
        statusItem.isVisible = Defaults[.showInputModeStatus] && InputSource.shared.isSelected()
    }
}
