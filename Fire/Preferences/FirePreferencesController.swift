//
//  FirePreferencesController.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI

/// 原生 SwiftUI 偏好设置窗口控制器，替代基于 Settings 库的实现
///
/// 使用 NSWindow + NSHostingController 驱动 NativePreferencesView，
/// 通过 @Published selectedPane 实现跨组件状态同步。
/// ObservableObject 协议使该类可作为 @EnvironmentObject 注入 SwiftUI 视图层级。
class FirePreferencesController: NSObject, NSWindowDelegate, ObservableObject {
    /// 当前选中的面板标识，由 NativePreferencesView 同步写入，也可供外部 showPane() 调用修改
    @Published var selectedPane: String = "基本"

    private var window: NSWindow?
    static let shared = FirePreferencesController()

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private func createWindow() -> NSWindow {
        let contentView = NativePreferencesView()
            .environmentObject(self)
        let hostingController = NSHostingController(rootView: contentView)
        let win = NSWindow(contentViewController: hostingController)
        win.title = selectedPane
        win.delegate = self
        win.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        win.isReleasedWhenClosed = false
        win.setContentSize(NSSize(width: 680, height: 520))
        win.minSize = NSSize(width: 300, height: 400)
        win.center()
        return win
    }

    func showPane(_ name: String) {
        selectedPane = name
        show()
    }

    func show() {
        if window == nil {
            window = createWindow()
            // 首次显示时设为 regular，之后不再切换以保持 dock 图标稳定
            NSApp.setActivationPolicy(.regular)
            setupMainMenu()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 补全主菜单中缺失的「隐藏」等系统菜单项，使 Cmd+H / Cmd+Option+H 可用
    private func setupMainMenu() {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
        // 避免重复添加
        if appMenu.items.contains(where: { $0.action == #selector(NSApplication.hide(_:)) }) {
            return
        }
        // 在「关闭」菜单项后插入 Hide / Hide Others / Show All
        if let closeIdx = appMenu.items.firstIndex(where: {
            $0.action == #selector(NSWindow.performClose(_:))
        }) {
            let hideItem = NSMenuItem(title: "隐藏 Fire", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
            hideItem.target = NSApp

            let hideOthersItem = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            hideOthersItem.keyEquivalentModifierMask = [.command, .option]
            hideOthersItem.target = NSApp

            let showAllItem = NSMenuItem(title: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
            showAllItem.target = NSApp

            appMenu.items.insert(NSMenuItem.separator(), at: closeIdx + 1)
            appMenu.items.insert(hideItem, at: closeIdx + 2)
            appMenu.items.insert(hideOthersItem, at: closeIdx + 3)
            appMenu.items.insert(showAllItem, at: closeIdx + 4)
        }
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        window = nil
        // 关闭偏好窗口后隐藏 Dock 图标，恢复输入法应有的后台运行状态
        NSApp.setActivationPolicy(.accessory)
    }
}
