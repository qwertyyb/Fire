//
//  ShortcutsPane.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/15.
//

import Defaults
import SwiftUI

struct ShortcutsPane: View {
    @Default(.quickCombineShortcut) private var storedQuickCombineShortcut
    @Default(.pinCandidateShortcut) private var storedPinCandidateShortcut
    @Default(.deleteCandidateShortcut) private var storedDeleteCandidateShortcut

    var body: some View {
        Form {
            Section {
                PreferenceShortcutRow(
                    title: "快速组词",
                    caption: "无输入码时触发",
                    role: .quickCombine,
                    mode: .fullKey,
                    quickCombineShortcut: quickCombineShortcutBinding,
                    pinCandidateShortcut: pinCandidateShortcutBinding,
                    deleteCandidateShortcut: deleteCandidateShortcutBinding
                )
                PreferenceShortcutRow(
                    title: "候选词置顶",
                    caption: "修饰键 + 数字 1–9",
                    role: .pinCandidate,
                    mode: .digit,
                    quickCombineShortcut: quickCombineShortcutBinding,
                    pinCandidateShortcut: pinCandidateShortcutBinding,
                    deleteCandidateShortcut: deleteCandidateShortcutBinding
                )
                PreferenceShortcutRow(
                    title: "删除候选词",
                    caption: "修饰键 + 数字 1–9",
                    role: .deleteCandidate,
                    mode: .digit,
                    quickCombineShortcut: quickCombineShortcutBinding,
                    pinCandidateShortcut: pinCandidateShortcutBinding,
                    deleteCandidateShortcut: deleteCandidateShortcutBinding
                )
            } header: {
                Text("快捷键")
            } footer: {
                Text("置顶与删词需在按住修饰键后按数字 1–9 确认。")
            }
        }
        .formStyle(.grouped)
    }

    private var quickCombineShortcutBinding: Binding<InputShortcut?> {
        Binding(
            get: { storedQuickCombineShortcut.value },
            set: { storedQuickCombineShortcut = StoredInputShortcut(value: $0, placeholder: .defaultQuickCombine) }
        )
    }

    private var pinCandidateShortcutBinding: Binding<DigitInputShortcut?> {
        Binding(
            get: { storedPinCandidateShortcut.value },
            set: { storedPinCandidateShortcut = StoredDigitInputShortcut(value: $0, placeholder: .defaultPinCandidate) }
        )
    }

    private var deleteCandidateShortcutBinding: Binding<DigitInputShortcut?> {
        Binding(
            get: { storedDeleteCandidateShortcut.value },
            set: { storedDeleteCandidateShortcut = StoredDigitInputShortcut(value: $0, placeholder: .defaultDeleteCandidate) }
        )
    }
}

#Preview {
    ShortcutsPane()
}
