//
//  ApplicationPane.swift
//  Fire
//
//  Created by 虚幻 on 2021/7/17.
//  Copyright © 2021 qwertyyb. All rights reserved.
//

import SwiftUI
import Defaults

struct ApplicationSettingItemView: View {
    var settingItem: ApplicationSettingItem
    let onDelete: () -> Void
    let onChange: () -> Void

    private func getDisplayName(_ identifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return identifier
        }
        let displayName = FileManager.default.displayName(atPath: url.path)
        return "\(displayName)(\(identifier))"
    }

    private func getIcon(_ identifier: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: getIcon(settingItem.bundleIdentifier))
                .resizable()
                .frame(width: 20, height: 20)
            Text(getDisplayName(settingItem.bundleIdentifier))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Picker("", selection: Binding<InputModeSetting>(get: {
                settingItem.inputModeSetting
            }, set: { inputModeSetting in
                settingItem.objectWillChange.send()
                settingItem.inputModeSetting = inputModeSetting
                onChange()
            })) {
                Text("五笔").tag(InputModeSetting.zhhans)
                Text("英文").tag(InputModeSetting.enUS)
            }
            .labelsHidden()
            .frame(width: 70)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        Divider()
    }
}

// MARK: - 偏好设置面板（迁移自 Settings 库，改用原生 ScrollView + VStack）

struct ApplicationPane: View {
    @Default(.keepAppInputMode) private var keepAppInputMode
    @Default(.appSettings) private var appSettings
    @Default(.disableEnMode) private var disableEnMode
    @Default(.appInputModeTipShowTime) private var appInputModeTipShowTime

    private func addApp() {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask).first
        openPanel.prompt = "选择应用"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.applicationBundle]
        // 使用 guard 语句提前退出并安全解包，消除强制解包风险，减少代码嵌套，使主逻辑路径更清晰。
        guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
        let selectedPath = url.path
        guard let bundle = Bundle(path: selectedPath) else { return }
        guard let identifier = bundle.bundleIdentifier else { return }

        appSettings[identifier] = ApplicationSettingItem(bundleId: identifier, inputMs: .enUS)
    }
    private func removeApp(_ settingItem: ApplicationSettingItem) {
        appSettings.removeValue(forKey: settingItem.bundleIdentifier)
    }

    var body: some View {
        Form {
            Section {
                PreferenceToggleRow(title: "保持应用最后使用的输入模式", isOn: $keepAppInputMode)
                Text("仅保留最近使用的\(InputModeCache.shared.capacity)个应用的输入模式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("自动切换")
            }
            Section {
                PreferencePickerRow(title: "显示提示") {
                    Picker("", selection: $appInputModeTipShowTime) {
                        Text("仅在变化时显示").tag(AppInputModeTipShowTime.onlyChanged)
                        Text("总是显示").tag(AppInputModeTipShowTime.always)
                        Text("不显示").tag(AppInputModeTipShowTime.none)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                HStack {
                    Text("应用设置")
                    Spacer()
                    Button(action: addApp) {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                    .controlSize(.small)
                }
                if appSettings.count > 0 {
                    VStack(spacing: 0) {
                        ForEach(appSettings.values.sorted(by: { a, b in
                            a.createdTimestamp < b.createdTimestamp
                        })) { settingItem in
                            ApplicationSettingItemView(settingItem: settingItem) {
                                removeApp(settingItem)
                            } onChange: {
                                appSettings[settingItem.bundleIdentifier] = settingItem
                                Defaults[.appSettings] = appSettings
                            }
                        }
                    }
                    .background(Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("添加应用可单独设置该应用下默认使用英文或五笔")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            } header: {
                Text("应用设置")
            }
            .disabled(disableEnMode)
        }
        .formStyle(.grouped)
    }
}

// 采用 Xcode 15 引入的 #Preview 宏语法，替代旧版 PreviewProvider 协议，使预览代码更简洁直观。
#Preview {
    ApplicationPane()
}
