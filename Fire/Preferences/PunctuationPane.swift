//
//  PunctuationPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/6/27.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Defaults

/// 用于构建全量符号列表的 per-key 候选（仅作汇总来源）
fileprivate let punctuationPickerOptions: [String: [String]] = [
    ",": [",", "，"],
    ".": [".", "。"],
    "/": ["/", "、"],
    ";": [";", "；"],
    "'": ["'", "‘", "’"],
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
    "\"": ["\"", "“", "”"],
    "<": ["<", "《", "「", "『", "【", "〔"],
    ">": [">", "》", "」", "』", "】", "〕"],
    "?": ["?", "？"],
]

/// 所有按键共享的全量可选符号
fileprivate let allPunctuationSymbols: [String] = {
    var seen = Set<String>()
    var symbols: [String] = []

    func append(_ symbol: String) {
        guard seen.insert(symbol).inserted else { return }
        symbols.append(symbol)
    }

    for key in defaultPunctuationMapping.keys.sorted() {
        append(key)
        for option in punctuationPickerOptions[key] ?? [] {
            append(option)
        }
    }
    for mapping in defaultPunctuationMapping.values {
        switch mapping {
        case .commit(let text):
            append(text)
        case .candidates(let list):
            list.forEach { append($0) }
        case .pair(let left, let right):
            append(left)
            append(right)
        }
    }
    return symbols
}()

fileprivate func defaultMapping(for key: String) -> PunctuationMapping {
    defaultPunctuationMapping[key] ?? .commit(key)
}

fileprivate func mappingForKind(_ kind: PunctuationMapping.Kind, key: String) -> PunctuationMapping {
    let fallback = defaultMapping(for: key)
    switch kind {
    case .commit:
        return .commit(fallback.primaryOutput)
    case .candidates:
        if case .candidates(let list) = fallback {
            return .candidates(list)
        }
        let primary = fallback.primaryOutput
        let secondary = allPunctuationSymbols.first { $0 != primary } ?? primary
        return .candidates([primary, secondary])
    case .pair:
        if case .pair(let left, let right) = fallback {
            return .pair(left: left, right: right)
        }
        let left = fallback.primaryOutput
        let right = allPunctuationSymbols.first { $0 != left } ?? left
        return .pair(left: left, right: right)
    }
}

fileprivate func mappingSummary(_ mapping: PunctuationMapping) -> String {
    switch mapping {
    case .commit(let text):
        return text
    case .candidates(let list):
        return list.joined(separator: " ")
    case .pair(let left, let right):
        return "\(left)…\(right)"
    }
}

struct PunctuationPane: View {
    @Default(.punctuationMode) private var punctuationMode
    @Default(.punctuationMappingType) private var punctuationMappingType
    @Default(.punctuationCustomMapping) private var punctuationCustomMapping
    @Default(.enableDotAfterNumber) private var enableDotAfterNumber
    @Default(.enableColonAfterNumber) private var enableColonAfterNumber
    @Default(.enablePunctuationAutoPair) private var enablePunctuationAutoPair

    private var sortedMappingKeys: [String] {
        defaultPunctuationMapping.keys.sorted()
    }

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
                PreferencePickerRow(title: "标点符号") {
                    Picker("", selection: $punctuationMode) {
                        Text("半角").tag(PunctuationMode.enUs)
                        Text("全角").tag(PunctuationMode.zhhans)
                    }
                    .labelsHidden()
                }
                if punctuationMode == .zhhans {
                    PreferencePickerRow(title: "全角映射方案") {
                        Picker("", selection: $punctuationMappingType) {
                            Text("默认").tag(PunctuationMappingType.default)
                            Text("自定义").tag(PunctuationMappingType.custom)
                        }
                        .labelsHidden()
                    }
                }
            } header: {
                Text("标点方案")
            }
            if punctuationMode == .zhhans && punctuationMappingType == .custom {
                Section {
                    HStack {
                        Text("按键")
                            .frame(width: 28, alignment: .center)
                        Text("方式")
                            .frame(width: 64, alignment: .leading)
                        Spacer(minLength: 8)
                        Text("映射")
                            .frame(width: 140, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(sortedMappingKeys, id: \.self) { key in
                        PunctuationCustomMappingRow(
                            key: key,
                            mapping: bindingForMapping(key)
                        )
                    }
                } header: {
                    Text("自定义符号映射")
                } footer: {
                    Text("每个按键均可设为上屏、选择或成对。")
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: punctuationMappingType) { newValue in
            if newValue == .custom {
                ensureCustomMappingInitialized()
            }
        }
        .onAppear {
            ensureCustomMappingInitialized()
        }
    }

    private func ensureCustomMappingInitialized() {
        if punctuationCustomMapping.isEmpty {
            punctuationCustomMapping = defaultPunctuationMapping
        }
    }

    private func bindingForMapping(_ key: String) -> Binding<PunctuationMapping> {
        Binding(
            get: {
                punctuationCustomMapping[key] ?? defaultMapping(for: key)
            },
            set: { newValue in
                punctuationCustomMapping[key] = newValue
            }
        )
    }
}

private struct PunctuationCustomMappingRow: View {
    let key: String
    @Binding var mapping: PunctuationMapping

    @State private var showsCandidateEditor = false

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.body.monospaced())
                .frame(width: 28, alignment: .center)

            Picker("方式", selection: kindBinding) {
                ForEach(PunctuationMapping.Kind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 64, alignment: .leading)

            Spacer(minLength: 8)

            trailingEditor
        }
    }

    private var kindBinding: Binding<PunctuationMapping.Kind> {
        Binding(
            get: { mapping.kind },
            set: { mapping = mappingForKind($0, key: key) }
        )
    }

    @ViewBuilder
    private var trailingEditor: some View {
        switch mapping.kind {
        case .commit:
            commitPicker
        case .candidates:
            candidatesControl
        case .pair:
            pairEditor
        }
    }

    private var commitPicker: some View {
        Picker("", selection: commitBinding) {
            ForEach(allPunctuationSymbols, id: \.self) { symbol in
                Text(symbol).tag(symbol)
            }
        }
        .labelsHidden()
        .frame(width: 140, alignment: .trailing)
    }

    private var commitBinding: Binding<String> {
        Binding(
            get: {
                if case .commit(let text) = mapping { return text }
                return mapping.primaryOutput
            },
            set: { mapping = .commit($0) }
        )
    }

    private var candidatesControl: some View {
        Button {
            showsCandidateEditor = true
        } label: {
            HStack(spacing: 4) {
                Text(mappingSummary(mapping))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 140, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsCandidateEditor, arrowEdge: .bottom) {
            CandidatesEditorPopover(mapping: $mapping)
        }
    }

    private var pairEditor: some View {
        HStack(spacing: 6) {
            Picker("", selection: pairLeftBinding) {
                ForEach(allPunctuationSymbols, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 56)
            Text("→")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Picker("", selection: pairRightBinding) {
                ForEach(allPunctuationSymbols, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 56)
        }
        .frame(width: 140, alignment: .trailing)
    }

    private var pairLeftBinding: Binding<String> {
        Binding(
            get: {
                if case .pair(let left, _) = mapping { return left }
                return allPunctuationSymbols[0]
            },
            set: { newLeft in
                let right: String
                if case .pair(_, let r) = mapping {
                    right = r
                } else {
                    right = allPunctuationSymbols.first { $0 != newLeft } ?? newLeft
                }
                mapping = .pair(left: newLeft, right: right)
            }
        )
    }

    private var pairRightBinding: Binding<String> {
        Binding(
            get: {
                if case .pair(_, let right) = mapping { return right }
                return allPunctuationSymbols.count > 1 ? allPunctuationSymbols[1] : allPunctuationSymbols[0]
            },
            set: { newRight in
                let left: String
                if case .pair(let l, _) = mapping {
                    left = l
                } else {
                    left = allPunctuationSymbols[0]
                }
                mapping = .pair(left: left, right: newRight)
            }
        )
    }
}

private struct CandidatesEditorPopover: View {
    @Binding var mapping: PunctuationMapping

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择符号")
                    .font(.headline)
                ForEach(allPunctuationSymbols, id: \.self) { symbol in
                    Toggle(symbol, isOn: candidateToggleBinding(for: symbol))
                }
                Text("至少保留 2 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(width: 200, height: 320)
    }

    private func candidateToggleBinding(for symbol: String) -> Binding<Bool> {
        Binding(
            get: {
                guard case .candidates(let list) = mapping else { return false }
                return list.contains(symbol)
            },
            set: { isOn in
                var list: [String]
                if case .candidates(let current) = mapping {
                    list = current
                } else {
                    list = Array(allPunctuationSymbols.prefix(2))
                }
                if isOn {
                    if !list.contains(symbol) { list.append(symbol) }
                } else if list.count > 2 {
                    list.removeAll { $0 == symbol }
                }
                list = allPunctuationSymbols.filter { list.contains($0) }
                mapping = .candidates(list)
            }
        )
    }
}

#Preview {
    PunctuationPane()
}
