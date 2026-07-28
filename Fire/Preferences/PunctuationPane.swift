//
//  PunctuationPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/6/27.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Defaults

// MARK: - 偏好设置面板（迁移自 Settings 库，改用原生 ScrollView + VStack）

/// 自定义映射面板下拉候选（与 fullwidthPunctuation 独立维护）
fileprivate let punctuationPickerOptions: [String: [String]] = [
    ",": [",", "，"],
    ".": [".", "。"],
    "/": ["/", "、"],
    ";": [";", "；"],
    "'": ["'", "‘"],
    "[": ["[", "【", "「", "『", "〔"],
    "]": ["]", "】", "」", "』", "〕"],
    "`": ["`"],
    "!": ["!", "！"],
    "@": ["@"],
    "#": ["#"],
    "$": ["$", "￥"],
    "%": ["%", "％"],
    "^": ["^", "……"],
    "&": ["&"],
    "*": ["*", "＊"],
    "(": ["(", "（"],
    ")": [")", "）"],
    "-": ["-"],
    "_": ["_", "——"],
    "+": ["+"],
    "=": ["="],
    "~": ["~", "～"],
    "{": ["{", "「", "【", "『", "〔"],
    "\\": ["\\", "、"],
    "|": ["|", "｜"],
    "}": ["}", "」", "】", "』", "〕"],
    ":": [":", "："],
    "\"": ["\"", "“"],
    "<": ["<", "《", "「", "『", "【", "〔"],
    ">": [">", "》", "」", "』", "】", "〕"],
    "?": ["?", "？"],
]

struct PunctuationPane: View {
    @Default(.punctuationMode) private var punctuationMode
    @Default(.customPunctuationSettings) private var customPunctuationSettings
    @Default(.enableDotAfterNumber) private var enableDotAfterNumber
    @Default(.enableColonAfterNumber) private var enableColonAfterNumber
    @Default(.enablePunctuationAutoPair) private var enablePunctuationAutoPair
    var body: some View {
        Form {
            Section {
                PreferenceToggleRow(title: "数字后输入“。”自动转为“.”", caption: "适用于如 1.5 小数输入场景", isOn: $enableDotAfterNumber)
                PreferenceToggleRow(title: "数字后输入“：”自动转为“:”", caption: "适用于如 12:45 时间输入场景", isOn: $enableColonAfterNumber)
                PreferenceToggleRow(title: "成对标点配对输出", isOn: $enablePunctuationAutoPair)
            } header: {
                Text("自动转换")
            }
            Section {
                PreferencePickerRow(title: "标点符号映射") {
                    Picker("", selection: $punctuationMode) {
                        Text("半角").tag(PunctuationMode.enUs)
                        Text("全角").tag(PunctuationMode.zhhans)
                        Text("自定义映射").tag(PunctuationMode.custom)
                    }
                    .labelsHidden()
                }
            } header: {
                Text("标点方案")
            }
            Section {
                VStack(spacing: 0) {
                    // 表头
                    HStack {
                        Text("按键")
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(width: 160, alignment: .center)
                        Text("→")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                        Text("输出")
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(width: 160, alignment: .center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0.15))

                    Divider()

                    // 映射行
                    VStack(spacing: 0) {
                        ForEach(customPunctuationSettings.sorted(by: <), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.body.monospaced())
                                    .frame(width: 160, alignment: .center)
                                Text("→")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                                Picker("", selection: Binding<String>(
                                    get: { value },
                                    set: { customPunctuationSettings[key] = $0 }
                                )) {
                                    ForEach(punctuationPickerOptions[key] ?? [key], id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .background(Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(punctuationMode != .custom)
            } header: {
                Text("自定义符号映射")
            }
        }
        .formStyle(.grouped)
    }
}

// 采用 Xcode 15 引入的 #Preview 宏语法，替代旧版 PreviewProvider 协议，使预览代码更简洁直观。
#Preview {
    PunctuationPane()
}
