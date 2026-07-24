//
//  PreferencePickerRow.swift
//  Fire
//
//  Created by 虚幻 on 2026/7/12.
//  Copyright © 2026 qwertyyb. All rights reserved.
//

import SwiftUI

/// 首选项中的标签 + Picker 行，用 HStack 保证标题、说明与控件垂直居中。
struct PreferencePickerRow<Content: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            content()
        }
    }
}

/// 首选项中的标签 + Toggle 行，布局与 PreferencePickerRow 一致。
struct PreferenceToggleRow: View {
    let title: String
    var caption: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

#Preview("Picker") {
    Form {
        PreferencePickerRow(title: "输入法方案") {
            Picker("", selection: .constant(CodeMode.wubi)) {
                Text("五笔").tag(CodeMode.wubi)
            }
            .labelsHidden()
        }
        PreferencePickerRow(title: "拆字版本", caption: "仅五笔拆字提示生效") {
            Picker("", selection: .constant(SpellingScheme.wubi86)) {
                Text("86").tag(SpellingScheme.wubi86)
            }
            .labelsHidden()
        }
    }
    .formStyle(.grouped)
    .frame(width: 480)
}

#Preview("Toggle") {
    Form {
        PreferenceToggleRow(title: "4码唯一上屏", isOn: .constant(true))
        PreferenceToggleRow(title: "第五码顶字上屏", caption: "仅五笔方案生效", isOn: .constant(false))
    }
    .formStyle(.grouped)
    .frame(width: 480)
}
