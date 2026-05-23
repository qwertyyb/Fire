//
//  PreferencesView.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/18.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Settings
import Defaults

struct GeneralPane: View {

    @Default(.codeMode) private var code
    @Default(.candidateCount) private var candidateCount
    @Default(.wubiAutoCommit) private var wubiAutoCommit
    @Default(.wubiCodeTip) private var wubiCodeTip
    @Default(.showCodeInWindow) private var showCodeInWindow
    @Default(.candidatesDirection) private var candidatesDirection
    @Default(.extraCandidateSelectKeys) private var extraCandidateSelectKeys
    @Default(.inputModeTipWindowType) private var inputModeTipWindowType
    @Default(.zKeyQuery) private var zKeyQuery
    @Default(.toggleInputModeKey) private var toggleInputModeKey
    @Default(.disableEnMode) private var disableEnMode
    @Default(.disableTempEnMode) private var disableTempEnMode
    @Default(.showInputModeStatus) private var showInputModeStatus
    @Default(.enableWhitespaceBetweenZhEn) private var enableWhitespaceBetweenZhEn

    var body: some View {
        Settings.Container(contentWidth: 450.0) {
            Settings.Section(title: "") {
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
                            HStack {
                                Picker("二三候选词额外选择键", selection: $extraCandidateSelectKeys) {
                                    Text("禁用").tag(ExtraCandidateSelectKeys.disabled)
                                    Text(";'").tag(ExtraCandidateSelectKeys.semicolonQuote)
                                    Text(",.").tag(ExtraCandidateSelectKeys.commaPeriod)
                                }
                                Spacer(minLength: 20)
                            }
                        }
                    }
                    GroupBox(label: Text("中英文切换")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle("禁止切换英文", isOn: $disableEnMode)
                                Spacer()
                                Toggle("状态栏显示", isOn: $showInputModeStatus)
                            }
                            HStack {
                                Toggle("中文与英文/数字之间插入空格", isOn: $enableWhitespaceBetweenZhEn)
                                Spacer()
                                Toggle("禁用;键临时英文模式", isOn: $disableTempEnMode)
                            }
                            HStack {
                                Picker("快捷键", selection: $toggleInputModeKey) {
                                    Text("control").tag(ModifierKey.control)
                                    Text("shift").tag(ModifierKey.shift)
                                    Text("左shift").tag(ModifierKey.leftShift)
                                    Text("右shift").tag(ModifierKey.rightShift)
                                    Text("option").tag(ModifierKey.option)
                                    Text("command").tag(ModifierKey.command)
                                    Text("fn").tag(ModifierKey.function)
                                }
                                .disabled(disableEnMode)
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
                                .disabled(disableEnMode)
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
