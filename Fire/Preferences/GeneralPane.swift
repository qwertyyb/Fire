//
//  PreferencesView.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/18.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Defaults

// MARK: - 偏好设置面板（迁移自 Settings 库）
//
// 每个面板原使用 Settings.Container/Section 包装，现改用原生 ScrollView + VStack。
// 布局和功能不变，仅移除对三方库 Settings 的依赖。

struct GeneralPane: View {

    @Default(.codeMode) private var code
    @Default(.candidateCount) private var candidateCount
    @Default(.wubiAutoCommit) private var wubiAutoCommit
    @Default(.wubiFifthCommit) private var wubiFifthCommit
    @Default(.candidateHintMode) private var candidateHintMode
    @Default(.enableGBK) private var enableGBK
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
    @Default(.spellingScheme) private var spellingScheme
    @Default(.chineseOutputMode) private var chineseOutputMode
    @Default(.enableExactMatch) private var enableExactMatch
    @Default(.celebrationEffect) private var celebrationEffect
    @Default(.hotkeyModifier) private var hotkeyModifier

    var body: some View {
        Form {
            Section {
                LabeledContent("输入法方案") {
                    Picker("", selection: $code) {
                        Text("五笔").tag(CodeMode.wubi)
                        Text("拼音").tag(CodeMode.pinyin)
                        Text("五笔拼音混合").tag(CodeMode.wubiPinyin)
                    }
                    .labelsHidden()
                }
                LabeledContent("反查提示") {
                    Picker("", selection: $candidateHintMode) {
                        Text("不提示").tag(CandidateHintMode.none)
                        Text("五笔编码").tag(CandidateHintMode.wubiCode)
                        Text("拼音音调").tag(CandidateHintMode.pinyin)
                        Text("五笔拆字").tag(CandidateHintMode.spelling)
                    }
                    .labelsHidden()
                }
                LabeledContent("五笔版本") {
                    Picker("", selection: $spellingScheme) {
                        Text("86").tag(SpellingScheme.wubi86)
                        Text("98").tag(SpellingScheme.wubi98)
                        Text("06").tag(SpellingScheme.wubi06)
                    }
                    .labelsHidden()
                    .disabled(candidateHintMode != .spelling)
                }
                Toggle("4码唯一上屏", isOn: $wubiAutoCommit)
                Toggle(isOn: $wubiFifthCommit) {
                    HStack(spacing: 8) {
                        Text("第五码顶字上屏")
                        Spacer()
                        Text("仅五笔方案生效")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .offset(y: 6)
                    }
                }
                .disabled(code != .wubi)
                Toggle(isOn: $enableExactMatch) {
                    HStack(spacing: 8) {
                        Text("精确匹配候选词")
                        Spacer()
                        Text("禁用逐码匹配")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .offset(y: 6)
                    }
                }
                Toggle(isOn: $zKeyQuery) {
                    HStack(spacing: 8) {
                        Text("Z键匹配查询")
                        Spacer()
                        Text("万能键")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .offset(y: 6)
                    }
                }
            } header: {
                Text("编码")
            }
            Section {
                LabeledContent("排列方式") {
                    Picker("", selection: $candidatesDirection) {
                        Text("横向").tag(CandidatesDirection.horizontal)
                        Text("竖向").tag(CandidatesDirection.vertical)
                    }
                    .labelsHidden()
                }
                LabeledContent("候选词数量") {
                    Picker("", selection: $candidateCount) {
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("5").tag(5)
                        Text("6").tag(6)
                        Text("7").tag(7)
                        Text("8").tag(8)
                        Text("9").tag(9)
                    }
                    .labelsHidden()
                }
                Toggle(isOn: $showCodeInWindow) {
                    HStack(spacing: 8) {
                        Text("显示输入码")
                        Spacer()
                        Text("不内嵌文本框")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .offset(y: 6)
                    }
                }
                Toggle("显示生僻字", isOn: $enableGBK)
                Toggle("输出繁体", isOn: Binding(
                    get: { chineseOutputMode == .traditional },
                    set: { chineseOutputMode = $0 ? .traditional : .simplified }
                ))
                LabeledContent("二三候选词额外选择键") {
                    Picker("", selection: $extraCandidateSelectKeys) {
                        Text("禁用").tag(ExtraCandidateSelectKeys.disabled)
                        Text(";'").tag(ExtraCandidateSelectKeys.semicolonQuote)
                        Text(",.").tag(ExtraCandidateSelectKeys.commaPeriod)
                    }
                    .labelsHidden()
                }
                LabeledContent("上屏庆祝效果") {
                    Picker("", selection: $celebrationEffect) {
                        Text("不显示").tag(CelebrationEffectType.none)
                        Text("鲜花").tag(CelebrationEffectType.flowers)
                        Text("星星").tag(CelebrationEffectType.stars)
                        Text("气球").tag(CelebrationEffectType.balloons)
                        Text("泡泡").tag(CelebrationEffectType.bubbles)
                        Text("喷火").tag(CelebrationEffectType.fireBlast)
                        Text("爱心").tag(CelebrationEffectType.hearts)
                        Text("蝴蝶").tag(CelebrationEffectType.butterflies)
                        Text("音符").tag(CelebrationEffectType.notes)
                        Text("彩纸").tag(CelebrationEffectType.paper)
                        Text("鸡蛋").tag(CelebrationEffectType.egg)
                    }
                    .labelsHidden()
                }
            } header: {
                Text("候选词")
            }
            Section {
                Toggle("禁止切换英文", isOn: $disableEnMode)
                Toggle("显示中英文状态", isOn: $showInputModeStatus)
                    .disabled(disableEnMode)
                LabeledContent("中英文切换快捷键") {
                    Picker("", selection: $toggleInputModeKey) {
                        HStack {
                            Image(systemName: "chevron.up")
                            Text("control")
                        }.tag(ModifierKey.control)
                        Label("shift", systemImage: "shift").tag(ModifierKey.shift)
                        Label("左shift", systemImage: "shift").tag(ModifierKey.leftShift)
                        Label("右shift", systemImage: "shift").tag(ModifierKey.rightShift)
                        Label("option", systemImage: "option").tag(ModifierKey.option)
                        Label("command", systemImage: "command").tag(ModifierKey.command)
                        Label("fn", systemImage: "globe").tag(ModifierKey.function)
                    }
                    .labelsHidden()
                    .disabled(disableEnMode)
                }
                LabeledContent("中英文状态提示位置") {
                    Picker("", selection: $inputModeTipWindowType) {
                        Text("屏幕中间").tag(InputModeTipWindowType.centerScreen)
                        Text("跟随输入框").tag(InputModeTipWindowType.followInput)
                        Text("不显示").tag(InputModeTipWindowType.none)
                    }
                    .labelsHidden()
                    .disabled(disableEnMode)
                }
                Toggle("中文与英文或数字之间插入空格", isOn: $enableWhitespaceBetweenZhEn)
                Toggle("禁用;键临时英文模式", isOn: $disableTempEnMode)
            } header: {
                Text("中英文切换")
            }
            Section {
                LabeledContent("热键修饰键") {
                    Picker("", selection: $hotkeyModifier) {
                        Text("Control").tag(HotkeyModifier.control)
                        Text("Option").tag(HotkeyModifier.option)
                        Text("Command").tag(HotkeyModifier.command)
                    }
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        KeyCap(hotkeyModifier.rawValue, icon: hotkeyIcon)
                        Text("+").font(.caption2).foregroundStyle(.tertiary)
                        KeyCap("数字")
                        Text("置顶候选词")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 6) {
                        KeyCap(hotkeyModifier.rawValue, icon: hotkeyIcon)
                        Text("+").font(.caption2).foregroundStyle(.tertiary)
                        KeyCap("shift", icon: "shift")
                        Text("+").font(.caption2).foregroundStyle(.tertiary)
                        KeyCap("数字")
                        Text("删除候选词")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 6) {
                        KeyCap(hotkeyModifier.rawValue, icon: hotkeyIcon)
                        Text("+").font(.caption2).foregroundStyle(.tertiary)
                        KeyCap("=")
                        Text("快速加词")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 4)
            } header: {
                Text("热键")
            }
        }
        .formStyle(.grouped)
    }
    private var hotkeyIcon: String {
        switch hotkeyModifier {
        case .control: return "chevron.up"
        case .option: return "option"
        case .command: return "command"
        }
    }
}

// 采用 Xcode 15 引入的 #Preview 宏语法，替代旧版 PreviewProvider 协议，使预览代码更简洁直观。
#Preview {
    GeneralPane()
}
