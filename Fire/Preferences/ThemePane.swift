//
//  ThemePane.swift
//  Fire
//
//  Created by 虚幻 on 2022/3/19.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences
import Defaults

struct ThemeConfigView: View {
    let themeConfig: ThemeConfig
    let isUsing: Bool
    let use: () -> Void

    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Text("\(themeConfig.name)(\(themeConfig.id))")
                Spacer()
                Text(themeConfig.author)
            }
            Button(isUsing ? "正使用" : "使用") {
                use()
            }
            .disabled(isUsing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

struct ThemePane: View {
    @Default(.themeConfig) var themeConfig
    @Default(.importedThemeConfig) var importedThemeConfig

    @State private var importedMessage = ""
    @State private var showAlert = false

    private func importTheme() {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        openPanel.prompt = "选择应用"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["json"]
        let result = openPanel.runModal()
        if result != NSApplication.ModalResponse.OK { return }
        let selectedPath = openPanel.url!.path
        guard let jsonData = try? String(contentsOfFile: selectedPath) else {
            importedMessage = "导入失败，请检查文件内容"
            showAlert = true
            return
        }
        guard let themeConfig = loadThemeConfig(jsonData: jsonData) else {
            importedMessage = "导入失败，请检查文件内容"
            showAlert = true
            return
        }
        if
            themeConfig.id.count <= 0 ||
            themeConfig.name.count <= 0 ||
            themeConfig.author.count <= 0
        {
            importedMessage = "请输入ID、名称或作者"
            showAlert = true
            return
        }
        Defaults[.importedThemeConfig] = themeConfig
        // 当前使用的和导入的输入法id一致，直接更新
        if Defaults[.themeConfig].id == themeConfig.id {
            Defaults[.themeConfig] = themeConfig
        }
        print(themeConfig)
    }

    func useThemeConfig(themeConfig: ThemeConfig) {
        Defaults[.themeConfig] = themeConfig
    }

    var body: some View {
        Preferences.Container(contentWidth: 450.0) {
            Preferences.Section(title: "") {
                HStack {
                    Button("创建主题") {
                        if let url = URL(string: "https://qwertyyb.github.io/Fire/theme.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Spacer()
                    if #available(macOS 12.0, *) {
                        Button("导入", action: importTheme)
                            .alert(importedMessage, isPresented: $showAlert) {
                                Button("确认", role: .cancel) {}
                            }
                    } else {
                        Button("导入", action: importTheme)
                    }
                }
                GroupBox(label: Text("默认主题")) {
                    ThemeConfigView(
                        themeConfig: defaultThemeConfig,
                        isUsing: themeConfig.id == defaultThemeConfig.id,
                        use: { useThemeConfig(themeConfig: defaultThemeConfig)}
                    )
                }
                if let importedThemeConfig = importedThemeConfig {
                    GroupBox(label: Text("导入的主题")) {
                        ThemeConfigView(
                            themeConfig: importedThemeConfig,
                            isUsing: importedThemeConfig.id == themeConfig.id,
                            use: {
                                useThemeConfig(themeConfig: importedThemeConfig)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ThemePane_Previews: PreviewProvider {
    static var previews: some View {
        ThemePane()
    }
}
