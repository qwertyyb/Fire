//
//  ThesaurusPane.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Settings
import Defaults

struct ThesaurusPane: View {
    @Default(.wbTablePath) private var wbTablePath
    @Default(.pyTablePath) private var pyTablePath

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
        if result == NSApplication.ModalResponse.OK {
            let selectedPath = openPanel.url!.path
            print(selectedPath)
            return selectedPath

        }
        return nil
    }

    var body: some View {
        Settings.Container(contentWidth: 450.0) {
            Settings.Section(title: "") {
                VStack(alignment: .leading) {
                    GroupBox(label: Text("词库设置")) {
                        VStack(spacing: 6) {
                            HStack {
                                Group {
                                    Text("五笔词库: ")
                                    Text(wbTablePath)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .truncationMode(.middle)
                                        .font(.system(size: 10))
                                      .foregroundColor(.white)
                                        .background(Color(.displayP3, red: 0.5, green: 0.5, blue: 0.5, opacity: 1))
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            if let path = selectFile() {
                                                Defaults[.wbTablePath] = path
                                            }
                                        }
                                }
                                Spacer()
                            }
                            HStack {
                                Group {
                                    Text("拼音词库: ")
                                    Text(pyTablePath)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .truncationMode(.middle)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .background(Color(.displayP3, red: 0.5, green: 0.5, blue: 0.5, opacity: 1))
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            if let path = selectFile() {
                                                Defaults[.pyTablePath] = path
                                            }
                                        }
                                }
                                Spacer()
                            }
                        }
                    }
                    Button(action: {
                        DictManager.shared.close()
                        buildDict()
                        DictManager.shared.reinit()
                    }, label: {
                        Text("建立索引")
                    })
                }
            }
        }
    }
}

struct ThesaurusPane_Previews: PreviewProvider {
    static var previews: some View {
        ThesaurusPane()
    }
}
