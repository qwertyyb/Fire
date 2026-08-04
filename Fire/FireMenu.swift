//
//  menu.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import AppKit
import Sparkle
import Defaults

extension FireInputController {
    /* -- menu actions start -- */
    @objc func openAbout (_ sender: Any!) {
        NSApp.activateAsAccessory()
        NSApp.orderFrontStandardAboutPanel(sender)
    }
    @objc func checkForUpdates(_ sender: Any!) {
        NSApp.activateAsAccessory()
        SUUpdater.shared()?.checkForUpdates(sender)
    }
    override func showPreferences(_ sender: Any!) {
        // 菜单 action 可能在非主线程调用，切到主线程确保 UI 操作安全
        DispatchQueue.main.async {
            FirePreferencesController.shared.show()
        }
    }
    @objc func showUserDictPrefs(_ sender: Any!) {
        // 同上，菜单 action 切回主线程再操作 UI
        DispatchQueue.main.async {
            FirePreferencesController.shared.showPane("用户词库")
        }
    }
    // 字根表窗口弱引用：关闭后自动置 nil，确保窗口释放时图片内存被回收
    private static weak var wubiRootWindow: NSWindow?

    /// 内置码表对应的字根表资源名；自定义码表返回 nil（不提供字根表）
    private static func builtInWubiRootTableName() -> String? {
        let path = Defaults[.wbTablePath]
        let standardized = URL(fileURLWithPath: path).standardizedFileURL
        let resourceURL = Bundle.main.resourceURL
        let mapping: [(String, String)] = [
            ("wb_table.txt", "86版五笔字型"),
            ("wb_98_table.txt", "98版五笔字型"),
            ("wb_06_table.txt", "06（新世纪）版五笔字型"),
        ]
        for (file, title) in mapping {
            if let p = resourceURL?.appendingPathComponent(file).path,
               URL(fileURLWithPath: p).standardizedFileURL == standardized {
                return title
            }
        }
        return nil
    }

    /// 打开五笔字根表窗口（仅内置 86/98/06 码表可用）
    ///
    /// 同一时间只允许打开一个字根表窗口，通过弱引用而非遍历 NSApp.windows 实现：
    ///   - 同版本窗口已存在 → 激活前置
    ///   - 不同版本窗口已存在 → 关闭旧窗口（weak 引用自动失效），加载新版
    ///   - 窗口被用户关闭 → isReleasedWhenClosed=false 保持窗口存活，下次打开时复用
    ///   - 切换版本时 → 先释放 contentView 释放图片内存，再关闭旧窗口
    @objc func showWubiRootTable(_ sender: Any!) {
        NSApp.activateAsAccessory()
        guard let fileName = Self.builtInWubiRootTableName() else {
            FireLog.input.info("wubi root table unavailable for custom wb table")
            return
        }
        // 复用现有窗口：同版本激活，不同版本替换内容
        if let existing = Self.wubiRootWindow {
            if existing.title == fileName {
                existing.makeKeyAndOrderFront(nil)
                return
            }
            // 不同版本：释放旧窗口资源后关闭，weak 引用自动置 nil
            existing.contentView = nil
            existing.close()
        }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "png") else {
            FireLog.input.error("wmwb image not found: \(fileName, privacy: .public)")
            return
        }
        guard let image = NSImage(contentsOf: url) else {
            FireLog.input.error("wmwb image load failed: \(url.absoluteString, privacy: .public)")
            return
        }

        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = NSRect(origin: .zero, size: NSSize(width: 900, height: 700))

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        scrollView.documentView = imageView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.allowsMagnification = true
        scrollView.maxMagnification = 4.0
        scrollView.minMagnification = 1.0

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = fileName
        window.contentView = scrollView
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        Self.wubiRootWindow = window
    }
    @objc func setApplicationMode(_ sender: Any!) {
        if let menuWrapper = sender as? [String: Any],
           let menuItem = menuWrapper["IMKCommandMenuItem"] as? NSMenuItem,
           let dict = menuItem.representedObject as? [String: Any],
           let bundleID = dict["bundleID"] as? String,
           let mode = dict["mode"] as? InputMode {
            FireLog.input.info("setApplicationMode, \(bundleID, privacy: .public), \(String(describing: mode), privacy: .public)")
            var appSettings = Defaults[.appSettings]
            appSettings[bundleID] = ApplicationSettingItem(bundleId: bundleID, inputMs: mode == .zhhans ? .zhhans : .enUS)
            Defaults[.appSettings] = appSettings
        }
    }
    @objc func setCodeMode(_ sender: Any) {
        // IMK 菜单回调的 sender 可能是包装字典，需取出真正的 NSMenuItem
        let item: NSMenuItem? = {
            if let menuItem = sender as? NSMenuItem { return menuItem }
            if let wrapper = sender as? [String: Any] {
                return wrapper["IMKCommandMenuItem"] as? NSMenuItem
            }
            return nil
        }()
        guard let mode = item?.representedObject as? CodeMode else { return }
        Defaults[.codeMode] = mode
    }

    override func menu() -> NSMenu! {
        FireLog.input.debug("menu")
        let menu = NSMenu()
        menu.items = [
            NSMenuItem(title: "首选项", action: #selector(showPreferences(_:)), keyEquivalent: ""),
            NSMenuItem(title: "用户词库", action: #selector(showUserDictPrefs(_:)), keyEquivalent: ""),
        ]
        // 查看五笔字根表：仅内置 86/98/06 码表提供
        if Self.builtInWubiRootTableName() != nil {
            menu.items.append(
                NSMenuItem(title: "查看五笔字根表", action: #selector(showWubiRootTable(_:)), keyEquivalent: "")
            )
        }
        menu.items.append(NSMenuItem.separator())
        let current = Defaults[.codeMode]
        let modeItems: [(String, CodeMode)] = [
            ("拼音", .pinyin),
            ("五笔", .wubi),
            ("五笔拼音混合", .wubiPinyin),
        ]
        menu.items.append(contentsOf: modeItems.map { title, mode in
            let item = NSMenuItem(title: title, action: #selector(setCodeMode(_:)), keyEquivalent: "")
            item.representedObject = mode
            item.state = mode == current ? .on : .off
            return item
        })
        
        if !Defaults[.disableEnMode],
            let controller = CandidatesWindow.shared.inputController,
            let bundleID = controller.client()?.bundleIdentifier() {
            var displayName = bundleID
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                displayName = FileManager.default.displayName(atPath: url.path)
            }
            let title = "设置“\(displayName)”的预设为\(Fire.engine.inputMode == .zhhans ? "中文" : "英文")"
            let menuItem = NSMenuItem(title: title, action: #selector(setApplicationMode(_:)), keyEquivalent: "")
            menuItem.representedObject = [
                "bundleID": bundleID,
                "mode": Fire.engine.inputMode
            ]
            menu.items.append(contentsOf: [
                NSMenuItem.separator(),
                menuItem,
            ])
        }
        menu.items.append(contentsOf: [
            NSMenuItem.separator(),
            NSMenuItem(title: "检查更新", action: #selector(checkForUpdates(_:)), keyEquivalent: ""),
            NSMenuItem(title: "关于业火输入法", action: #selector(openAbout(_:)), keyEquivalent: "")
        ])
        return menu
    }
}
