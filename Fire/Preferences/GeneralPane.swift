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
    @Default(.showCodeInWindow) private var showCodeInWindow
    @Default(.candidatesDirection) private var candidatesDirection
    @Default(.inputModeTipWindowType) private var inputModeTipWindowType
    @Default(.zKeyQuery) private var zKeyQuery
    @Default(.toggleInputModeKey) private var toggleInputModeKey

    var body: some View {
        Preferences.Container(contentWidth: 450.0) {
            Preferences.Section(title: "") {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox(label: Text("编码")) {
                        VStack(spacing: 12) {
                            HStack {
                                Picker("编码方案", selection: $code) {
                                    Text("五笔").tag(CodeMode.wubi)
                                    Text("拼音").tag(CodeMode.pinyin)
                                    Text("五笔拼音混合").tag(CodeMode.wubiPinyin)
                                }
                                .frame(width: 180)
                                Spacer(minLength: 50)
                            }
                            HStack {
                                Toggle("满4码唯一候选词直接上屏", isOn: $wubiAutoCommit)
                                Spacer(minLength: 50)
                                Toggle("提示五笔编码", isOn: $wubiCodeTip)
                                Spacer(minLength: 50)
                            }
                            HStack {
                                Toggle("z键查询", isOn: $zKeyQuery)
                                Spacer(minLength: 50)
                            }
                        }
                    }
                    GroupBox(label: Text("候选词")) {
                        VStack(spacing: 12) {
                            HStack {
                                Picker("候选词排列", selection: $candidatesDirection) {
                                    Text("横向").tag(CandidatesDirection.horizontal)
                                    Text("竖向").tag(CandidatesDirection.vertical)
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
                                Toggle("候选框显示输入码", isOn: $showCodeInWindow)
                                Spacer(minLength: 20)
                            }
                        }
                    }
                    GroupBox(label: Text("中英文切换")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("快捷键", selection: $toggleInputModeKey) {
                                    Text("control").tag(NSEvent.ModifierFlags.control.rawValue)
                                    Text("shift").tag(NSEvent.ModifierFlags.shift.rawValue)
                                    Text("option").tag(NSEvent.ModifierFlags.option.rawValue)
                                    Text("command").tag(NSEvent.ModifierFlags.command.rawValue)
                                }
                                Spacer(minLength: 50)
                                Picker(
                                    "提示框位置",
                                    selection: $inputModeTipWindowType
                                ) {
                                    Text("屏幕中间")
                                    .tag(InputModeTipWindowType.centerScreen)
                                    Text("跟随输入框")
                                    .tag(InputModeTipWindowType.followInput)
                                    Text("不显示")
                                    .tag(InputModeTipWindowType.none)
                                }
//                                .frame(width: 180)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct GeneralPane_Previews: PreviewProvider {
    static var previews: some View {
        GeneralPane()
    }
}
