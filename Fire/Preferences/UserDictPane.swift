//
//  UserDictPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/7/1.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Combine
import Defaults

/// 用户词表的一行数据
struct UserDictRow: Identifiable, Equatable {
    let id = UUID()
    var code: String
    var candidates: [String]

    static func == (lhs: UserDictRow, rhs: UserDictRow) -> Bool {
        lhs.code == rhs.code && lhs.candidates == rhs.candidates
    }
}

// MARK: - 偏好设置面板

struct UserDictPane: View {
    @State private var rows: [UserDictRow] = []
    @State private var savedSnapshot: [UserDictRow] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var confirmDeleteCandidate: (row: Int, candidate: Int)?
    @State private var confirmDeleteRow: Int?
    @State private var isModified = false

    var body: some View {
        Form {
            Section {
                // 快捷键说明
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        KeyCap("control", icon: "control")
                        Text("+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        KeyCap("=")
                        Text("引导快速组合新词并置顶")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 6) {
                        KeyCap("control", icon: "control")
                        Text("+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        KeyCap("option", icon: "option")
                        Text("+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        KeyCap("N")
                        Text("手动调整候选词顺序（置顶）")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                // 用户词表格
                List {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { (index, _) in
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                TextField("编码", text: $rows[index].code)
                                    .textFieldStyle(.plain)
                                    .font(.body.monospaced())
                                    .frame(width: 35)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0.15))
                                    .cornerRadius(4)
                                Text("→")
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(rows[index].candidates.indices, id: \.self) { ci in
                                            HStack(spacing: 2) {
                                                if ci > 0 {
                                                    Button {
                                                        rows[index].candidates.swapAt(ci - 1, ci)
                                                        isModified = true
                                                    } label: {
                                                        Image(systemName: "chevron.left")
                                                            .foregroundStyle(.secondary)
                                                            .font(.caption2)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                                TextField("候选项", text: $rows[index].candidates[ci])
                                                    .textFieldStyle(.plain)
                                                    .font(.body.monospaced())
                                                    .frame(minWidth: 20)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0.15))
                                                    .cornerRadius(4)
                                                Button {
                                                    confirmDeleteCandidate = (row: index, candidate: ci)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.secondary)
                                                        .font(.caption)
                                                }
                                                .buttonStyle(.plain)
                                                if ci < rows[index].candidates.count - 1 {
                                                    Button {
                                                        rows[index].candidates.swapAt(ci, ci + 1)
                                                        isModified = true
                                                    } label: {
                                                        Image(systemName: "chevron.right")
                                                            .foregroundStyle(.secondary)
                                                            .font(.caption2)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        Button {
                                            rows[index].candidates.append("")
                                            isModified = true
                                        } label: {
                                            Image(systemName: "plus.circle")
                                                .foregroundStyle(.blue)
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        .help("添加候选项")
                                    }
                                    .padding(.vertical, 4)
                                }
                                Button(role: .destructive) {
                                    confirmDeleteRow = index
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("删除此行")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minHeight: 200)

                HStack {
                    Button {
                        rows.append(UserDictRow(code: "", candidates: [""]))
                        isModified = true
                    } label: {
                        Image(systemName: "plus")
                        Text("添加编码")
                    }
                    Button("保存") {
                        saveData()
                        loadData()
                        isModified = false
                        alertMessage = "用户词库已保存"
                        showAlert = true
                    }
                    .tint(isModified ? .red : nil)
                    Spacer()
                    Button("导入") {
                        let panel = NSOpenPanel()
                        panel.title = "导入用户词库"
                        panel.allowedContentTypes = [.plainText]
                        guard panel.runModal() == .OK, let url = panel.url,
                              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                        DictManager.shared.updateUserDict(content)
                        loadData()
                        isModified = false
                        alertMessage = "用户词库已导入"
                        showAlert = true
                    }
                    Button("导出") {
                        let content = DictManager.shared.getUserDictContent()
                        let panel = NSSavePanel()
                        panel.title = "导出用户词库"
                        panel.nameFieldStringValue = "user_dict.txt"
                        panel.allowedContentTypes = [.plainText]
                        guard panel.runModal() == .OK, let url = panel.url else { return }
                        try? content.write(to: url, atomically: true, encoding: .utf8)
                        alertMessage = "用户词库已导出"
                        showAlert = true
                    }
                    Button("导出合并码表") {
                        let content = DictManager.shared.exportFullDictContent()
                        let panel = NSSavePanel()
                        panel.title = "导出码表（含用户词）"
                        panel.nameFieldStringValue = "wb_table_user_merged.txt"
                        panel.allowedContentTypes = [.plainText]
                        guard panel.runModal() == .OK, let url = panel.url else { return }
                        try? content.write(to: url, atomically: true, encoding: .utf8)
                        let lines = content.split(separator: "\n").count
                        alertMessage = "含用户词的码表已导出（\(lines) 条编码）"
                        showAlert = true
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("可使用日期和时间占位符作为候选词：")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 6) {
                        Text("示例：")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}")
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 0.2))
                            .cornerRadius(3)
                        Text(" →  2026-02-20 23:45:30")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("用户词")
            }
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            KeyCap("control", icon: "control")
                            Text("+")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            KeyCap("shift", icon: "shift")
                            Text("+")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            KeyCap("N")
                            Text("将对应候选词移除（对码表词屏蔽，对用户词删除并屏蔽）")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                BlockedWordsList()
                    .frame(maxWidth: .infinity)
            } header: {
                Text("屏蔽词")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadData)
        .onReceive(NotificationCenter.default.publisher(for: DictManager.userDictUpdated)) { _ in
            guard !isModified else { return }
            loadData()
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("好") {}
        }
        .confirmationDialog("删除候选项", isPresented: Binding(get: { confirmDeleteCandidate != nil }, set: { if !$0 { confirmDeleteCandidate = nil } })) {
            Button("删除", role: .destructive) {
                if let c = confirmDeleteCandidate {
                    rows[c.row].candidates.remove(at: c.candidate)
                    isModified = true
                    if rows[c.row].candidates.isEmpty {
                        rows.remove(at: c.row)
                    }
                }
                confirmDeleteCandidate = nil
            }
            Button("取消", role: .cancel) { confirmDeleteCandidate = nil }
        } message: {
            if let c = confirmDeleteCandidate, c.candidate < rows[c.row].candidates.count {
                Text("确认删除候选项「\(rows[c.row].candidates[c.candidate])」？")
            }
        }
        .confirmationDialog("删除编码", isPresented: Binding(get: { confirmDeleteRow != nil }, set: { if !$0 { confirmDeleteRow = nil } })) {
            Button("删除", role: .destructive) {
                if let idx = confirmDeleteRow {
                    rows.remove(at: idx)
                    isModified = true
                }
                confirmDeleteRow = nil
            }
            Button("取消", role: .cancel) { confirmDeleteRow = nil }
        } message: {
            if let idx = confirmDeleteRow, idx < rows.count {
                Text("确认删除编码「\(rows[idx].code)」及其所有候选项？")
            }
        }
        .onChange(of: rows) { _ in
            isModified = (rows != savedSnapshot)
        }
    }

    private func loadData() {
        let newRows = DictManager.shared.getUserDictRows().map { UserDictRow(code: $0.code, candidates: $0.candidates) }
        savedSnapshot = newRows
        rows = newRows
    }

    private func saveData() {
        let lines = rows
            .filter { !$0.code.isEmpty && !$0.candidates.isEmpty }
            .map { row in
                let candidates = row.candidates
                    .filter { !$0.isEmpty }
                    .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
                return ([row.code] + candidates).joined(separator: " ")
            }
            .joined(separator: "\n")
        DictManager.shared.updateUserDict(lines)
    }
}

/// 已屏蔽词列表
struct BlockedWordsList: View {
    @State private var words: [String] = []

    var body: some View {
        Group {
            if words.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
            } else {
                VStack(spacing: 0) {
                    ForEach(words, id: \.self) { word in
                        HStack {
                            Text(word).font(.callout)
                            Spacer()
                            Button("恢复") {
                                DictManager.shared.unblockWord(word)
                                words.removeAll { $0 == word }
                            }
                            .font(.caption)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { words = DictManager.shared.getBlockedWords() }
        .onReceive(NotificationCenter.default.publisher(for: DictManager.userDictUpdated)) { _ in
            words = DictManager.shared.getBlockedWords()
        }
    }
}

#Preview {
    UserDictPane()
}
