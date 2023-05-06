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
    private var showInputModeStatusSubscript: AnyCancellable?
    private init() {
        // 输入法变化时，根据当前选中状态切换显示
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "中"
        statusItem.button?.action = #selector(changeInputMode)
        statusItem.button?.target = self

        refreshVisibleStatus()

        showInputModeStatusSubscript = Defaults.publisher(.showInputModeStatus).sink { _ in
            self.refresh()
        }
    }

    deinit {
        showInputModeStatusSubscript?.cancel()
        showInputModeStatusSubscript = nil
    }

    @objc func changeInputMode() {
        Fire.shared.toggleInputMode()
    }

    private func refreshTitle() {
        statusItem.button?.title = Fire.shared.inputMode == .zhhans ? "中" : "英"
    }

    private func refreshVisibleStatus() {
        NSLog("StatusBar.refreshVisibleStatus: \(InputSource.shared.isSelected())")
        statusItem.isVisible = Defaults[.showInputModeStatus] && InputSource.shared.isSelected()
    }

    func refresh() {
        refreshVisibleStatus()
        refreshTitle()
    }
}
