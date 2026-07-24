//
//  ThesaurusPane.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Defaults

// MARK: - 内置五笔码表预设

private enum BuiltInWbTable: String, CaseIterable, Identifiable {
    case wubi86
    case wubi98
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wubi86: return "86"
        case .wubi98: return "98"
        case .custom: return "自定义"
        }
    }

    /// Bundle 内置码表路径；custom 无对应路径
    var resourcePath: String? {
        let name: String?
        switch self {
        case .wubi86: name = "wb_table.txt"
        case .wubi98: name = "wb_98_table.txt"
        case .custom: name = nil
        }
        guard let name else { return nil }
        return Bundle.main.resourceURL?.appendingPathComponent(name).path
    }

    var spellingScheme: SpellingScheme? {
        switch self {
        case .wubi86: return .wubi86
        case .wubi98: return .wubi98
        case .custom: return nil
        }
    }

    static func matching(path: String) -> BuiltInWbTable {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL
        for preset in [BuiltInWbTable.wubi86, .wubi98] {
            if let resourcePath = preset.resourcePath,
               URL(fileURLWithPath: resourcePath).standardizedFileURL == standardized {
                return preset
            }
        }
        return .custom
    }
}

// MARK: - 偏好设置面板

struct ThesaurusPane: View {
    @Default(.wbTablePath) private var wbTablePath
    @Default(.pyTablePath) private var pyTablePath
    @Default(.spellingScheme) private var spellingScheme
    @State private var selectedWbPreset: BuiltInWbTable = .wubi86
    @State private var pendingWbPreset: BuiltInWbTable?
    @State private var showRebuildConfirm = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var building = false
    @State private var builtWbPath = ""
    @State private var builtPyPath = ""

    private var isPathModified: Bool {
        wbTablePath != builtWbPath || pyTablePath != builtPyPath
    }

    /// 使用内置 86/98 时路径固定，禁止手选词库与手动重建（切换时已确认重建）
    private var isBuiltInWbPreset: Bool {
        selectedWbPreset == .wubi86 || selectedWbPreset == .wubi98
    }

    private var wbTablePresetBinding: Binding<BuiltInWbTable> {
        Binding(
            get: { selectedWbPreset },
            set: { applyWbTablePreset($0) }
        )
    }

    private func selectFile() -> String? {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = Bundle.main.resourceURL
        openPanel.prompt = "选择词库文件"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.text]
        let result = openPanel.runModal()
        if result == .OK, let url = openPanel.url {
            return url.path
        }
        return nil
    }

    private func syncSelectedPresetFromPath() {
        selectedWbPreset = BuiltInWbTable.matching(path: wbTablePath)
    }

    private func applyWbTablePreset(_ preset: BuiltInWbTable) {
        guard preset != selectedWbPreset else { return }
        switch preset {
        case .wubi86, .wubi98:
            // 先不改路径；确认重建后再应用，取消则分段控件保持原选中
            pendingWbPreset = preset
            showRebuildConfirm = true
        case .custom:
            // 仅切换到自定义模式，由下方词库选择与重建按钮操作
            selectedWbPreset = .custom
        }
    }

    private func confirmSwitchAndRebuild() {
        guard let preset = pendingWbPreset,
              let path = preset.resourcePath else {
            pendingWbPreset = nil
            return
        }
        wbTablePath = path
        if let scheme = preset.spellingScheme {
            spellingScheme = scheme
        }
        selectedWbPreset = preset
        pendingWbPreset = nil
        startRebuild()
    }

    private func cancelSwitchPreset() {
        pendingWbPreset = nil
        // selectedWbPreset 未改，分段控件回退到原选中
    }

    private func startRebuild() {
        building = true
        DictManager.shared.close()
        DispatchQueue.global().async {
            let success = buildDict()
            DispatchQueue.main.async {
                DictManager.shared.reinit()
                building = false
                if success {
                    builtWbPath = wbTablePath
                    builtPyPath = pyTablePath
                    let wbCount = DictManager.shared.queryBaseDictCount()
                    alertMessage = "索引建立完成（码表词: \(wbCount) 条）"
                } else {
                    alertMessage = "重建失败，请检查五笔词库和拼音词库文件路径是否正确"
                }
                showAlert = true
            }
        }
    }

    var body: some View {
        Form {
            Section {
                PreferencePickerRow(title: "五笔码表") {
                    Picker("", selection: wbTablePresetBinding) {
                        ForEach(BuiltInWbTable.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    .disabled(building)
                }
            } header: {
                Text("码表版本")
            } footer: {
                Text("切换 86/98 需确认后重建索引，并同步「拆字版本」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(spacing: 8) {
                    HStack {
                        Text("五笔词库")
                            .frame(width: 80, alignment: .leading)
                        Text(wbTablePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("选择…") {
                            if let path = selectFile() {
                                wbTablePath = path
                                syncSelectedPresetFromPath()
                            }
                        }
                        .controlSize(.small)
                        .disabled(building || isBuiltInWbPreset)
                    }
                    Divider()
                    HStack {
                        Text("拼音词库")
                            .frame(width: 80, alignment: .leading)
                        Text(pyTablePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("选择…") {
                            if let path = selectFile() {
                                pyTablePath = path
                            }
                        }
                        .controlSize(.small)
                        .disabled(building || isBuiltInWbPreset)
                    }
                }

                HStack {
                    Spacer()
                    Button(action: startRebuild) {
                        HStack(spacing: 8) {
                            if building {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(building ? "正在建立索引…" : "建立索引")
                        }
                    }
                    .disabled(building || isBuiltInWbPreset)
                    .tint(isPathModified && !isBuiltInWbPreset ? .red : nil)
                    Spacer()
                }
            } header: {
                Text("自定义词库")
            } footer: {
                Text(isBuiltInWbPreset
                     ? "当前使用内置码表，自定义词库与手动重建不可用。"
                     : "选择自定义词库文件后需重建索引才能生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            syncSelectedPresetFromPath()
            builtWbPath = wbTablePath
            builtPyPath = pyTablePath
        }
        .confirmationDialog(
            "切换到 \(pendingWbPreset?.label ?? "") 版五笔码表？",
            isPresented: $showRebuildConfirm,
            titleVisibility: .visible
        ) {
            Button("重建索引") {
                confirmSwitchAndRebuild()
            }
            Button("取消", role: .cancel) {
                cancelSwitchPreset()
            }
        } message: {
            Text("将切换码表并重建索引，期间可能短暂无法打字。取消则保持当前选中。")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("好") {}
        }
    }
}

#Preview {
    ThesaurusPane()
}
