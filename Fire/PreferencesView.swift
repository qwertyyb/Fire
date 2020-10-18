//
//  PreferencesView.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/18.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences
import Defaults

struct GeneralPane: View {

    @Default(.codeMode) private var code
    @Default(.candidateCount) private var candidateCount
    @Default(.wubiAutoCommit) private var wubiAutoCommit
    @Default(.wubiCodeTip) private var wubiCodeTip

    var body: some View {
        Preferences.Container(contentWidth: 450.0) {
            Preferences.Section(title: "") {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Picker("编码方案", selection: $code) {
                            Text("五笔").tag(CodeMode.wubi)
                            Text("拼音").tag(CodeMode.pinyin)
                            Text("五笔拼音混合").tag(CodeMode.wubiPinyin)
                        }
                        Spacer(minLength: 50)
                        Picker("候选词数量", selection: $candidateCount) {
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5").tag(5)
                            Text("6").tag(6)
                            Text("7").tag(7)
                            Text("8").tag(8)
                            Text("9").tag(9)
                        }
                    }
                    HStack {
                        Toggle("满4码唯一候选词直接上屏", isOn: $wubiAutoCommit)
                        Spacer(minLength: 50)
                        Toggle("提示五笔编码", isOn: $wubiCodeTip)
                        Spacer(minLength: 50)
                    }
                }
            }
        }
    }
}

struct AdvancedPane: View {
    var body: some View {
        Preferences.Container(contentWidth: 450.0) {
            Preferences.Section(title: "高级设置") {
                Text("高级设置")
            }
        }
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralPane()
    }
}
