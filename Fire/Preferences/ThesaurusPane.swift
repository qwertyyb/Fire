//
//  ThesaurusPane.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Defaults

// MARK: - 偏好设置面板（迁移自 Settings 库，改用原生 ScrollView + VStack）

struct ThesaurusPane: View {
    @Default(.wbTablePath) private var wbTablePath
    @Default(.pyTablePath) private var pyTablePath
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var building = false
    @State private var builtWbPath = ""
    @State private var builtPyPath = ""

    private var isPathModified: Bool {
        wbTablePath != builtWbPath || pyTablePath != builtPyPath
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
            let selectedPath = url.path
            return selectedPath

        }
        return nil
    }

    var body: some View {
        Form {
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
                                Defaults[.wbTablePath] = path
                            }
                        }
                        .controlSize(.small)
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
                                Defaults[.pyTablePath] = path
                            }
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("词库文件路径")
            }
            Section {
                HStack {
                    Spacer()
                    Button(action: {
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
                    }, label: {
                        HStack(spacing: 8) {
                            if building {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(building ? "正在建立索引…" : "建立索引")
                        }
                    })
                    .disabled(building)
                    .tint(isPathModified ? .red : nil)
                    Spacer()
                }
            } header: {
                Text("重建索引")
            } footer: {
                Text("修改词库文件后需重建索引才能生效")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            builtWbPath = wbTablePath
            builtPyPath = pyTablePath
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("好") {}
        }
    }
}

#Preview {
    ThesaurusPane()
}
