//
//  AppDelegate.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import AppKit
import InputMethodKit

@main  // Swift 5.3+ 推荐入口标记，替代 @NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var fire: Fire!
    var statistics: Statistics!
    var statusBar: StatusBar!
    var cliServer: FireCLIServer!

    func installInputSource() {
        print("install input source")
        InputSource.shared.registerInputSource()
        InputSource.shared.activateInputSource()
        InputSource.shared.selectInputSource { _ in
            NSApp.terminate(self)
        }
    }

    func stop() {
        InputSource.shared.deactivateInputSource()
        NSApp.terminate(nil)
    }

    private func commandHandler() -> Bool {
        if CommandLine.arguments.count > 1 {
            let command = CommandLine.arguments[1]
            if command == "--install" {
                print("[Fire] launch argument: \(command)")
                installInputSource()
                return false
            }
            if command == "--build-dict" {
                print("[Fire] launch argument: \(command)")
                print("[Fire] build dict")
                buildDict()
                NSApp.terminate(nil)
                return false
            }
            if command == "--stop" {
                print("[Fire] launch argument: \(command)")
                print("[Fire] stop")
                stop()
                return false
            }
            if command == "--get-mode" {
                let cli = FireCLI()
                cli.getMode()
                return false
            }
            if command == "--set-mode" {
                if CommandLine.arguments.count < 2 {
                    print("[Fire] commandHandler: no mode specifiy (enUs/zhhans)")
                }
                let mode = CommandLine.arguments[2]
                let showTip = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] != "false" : true
                let cli = FireCLI()
                cli.setMode(mode, showTip: showTip)
                return false
            }
        }
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !commandHandler() {
            return
        }
        _ = RadicalFontManager.shared
        NSLog("[Fire] app is running")
        fire = Fire.shared
        statistics = Statistics.shared
        statusBar = StatusBar.shared
        cliServer = FireCLIServer()
        registerURLHandler()

        if !hasDict() || !isDictSchemaCurrent() {
            NSLog("[Fire] dict missing or schema outdated, build dict")
            DictManager.shared.close()
            DispatchQueue.global(qos: .userInitiated).async {
                let success = buildDict()
                DispatchQueue.main.async {
                    if success {
                        DictManager.shared.reinit()
                    } else {
                        NSLog("[Fire] buildDict failed")
                    }
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // MARK: - URL Scheme

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }
        handleIncomingURL(url)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "fire" else { return }
        let host = url.host?.lowercased()
        let path = url.path.lowercased()

        // 兼容 fire://theme/import 与 fire://import-theme 两种写法
        let isImport = (host == "theme" && path == "/import") || host == "import-theme"
        guard isImport else { return }

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let dataItem = components.queryItems?.first(where: { $0.name == "data" }),
            let encoded = dataItem.value
        else {
            showImportAlert(success: false, message: "导入链接缺少 data 参数")
            return
        }

        guard let json = decodeBase64URL(encoded) else {
            showImportAlert(success: false, message: "导入链接的 data 解码失败")
            return
        }

        switch parseThemeConfig(jsonData: json) {
        case .failure(let error):
            showImportAlert(success: false, message: error.localizedDescription)
        case .success(let config):
            confirmAndImport(config)
        }
    }

    private func decodeBase64URL(_ s: String) -> String? {
        var str = s.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - (str.count % 4)
        if pad < 4 { str.append(String(repeating: "=", count: pad)) }
        guard let data = Data(base64Encoded: str) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func confirmAndImport(_ config: ThemeConfig) {
        let alert = NSAlert()
        alert.messageText = "导入主题 \(config.name)(\(config.id))？"
        alert.informativeText = "作者：\(config.author)\n确认后将覆盖现有的已导入主题。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "导入")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            applyImportedTheme(config)
            showImportAlert(success: true, message: "主题 \(config.name) 导入成功")
        }
    }

    private func showImportAlert(success: Bool, message: String) {
        let alert = NSAlert()
        alert.messageText = success ? "导入成功" : "导入失败"
        alert.informativeText = message
        alert.alertStyle = success ? .informational : .warning
        alert.addButton(withTitle: "确定")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
