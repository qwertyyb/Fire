//
//  UserDictPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/7/1.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences

class UserDictModel: ObservableObject {
    @Published var text: String = ""

    let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/" + Bundle.main.bundleIdentifier! + "/user-dict.txt"

    init() {
        self.text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    func write() {
        try? self.text.write(toFile: path, atomically: false, encoding: .utf8)
    }
}

struct UserDictPane: View {
    @StateObject private var userDict = UserDictModel()
    @State private var saved = false
    var body: some View {
        Preferences.Container(contentWidth: 450) {
            Preferences.Section(title: "") {
                Text("用户词库")
                if #available(macOS 11.0, *) {
                    TextEditor(text: $userDict.text)
                        .font(Font.system(size: 14))
                        .frame(height: 400)
                    Text("1. 编码需在行首")
                        .font(Font.system(size: 11))
                    Text("2. 编码和候选项之间需用空格分隔")
                        .font(Font.system(size: 11))
                    Text("3. 可以有多个候选项，每个候选项使用空格分隔")
                        .font(Font.system(size: 11))
                    HStack {
                        Spacer()
                        if #available(macOS 12.0, *) {
                            Button("保存") {
                                userDict.write()
                                DictManager.shared.updateUserDict()
                                saved = true
                            }
                            .alert("保存成功", isPresented: $saved) {
                            }
                        } else {
                            // Fallback on earlier versions
                            Button("保存") {
                                userDict.write()
                                DictManager.shared.updateUserDict()
                                print("saved")
                            }
                        }
                        Spacer()
                    }
                } else {
                    // Fallback on earlier versions
                    Text("暂不支持，请升级系统至11.0及以上")
                }
            }
        }
    }
}

struct UserDictPane_Previews: PreviewProvider {
    static var previews: some View {
        UserDictPane()
    }
}
