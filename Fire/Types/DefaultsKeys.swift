//
//  DefaultsKeys.swift
//  Fire
//
//  Created by qwertyyb on 2023/10/26.
//
//  Defaults 类型安全键值存储。迁移自 types.swift，聚焦偏好配置键。

import Foundation
import Defaults

// 上屏庆祝效果类型
enum CelebrationEffectType: String, Codable, Defaults.Serializable {
    case none     // 不显示
    case flowers  // 鲜花
    case stars    // 星星
    case balloons // 气球
    case bubbles  // 泡泡
    case fireBlast // 喷火
    case hearts   // 爱心
    case butterflies // 蝴蝶
    case notes    // 音符
    case paper    // 彩纸
    case egg      // 鸡蛋
}

extension Defaults.Keys {
    static let zKeyQuery = Key<Bool>("zKeyQuery", default: true)
    static let candidatesDirection = Key<CandidatesDirection>("candidatesDirection", default: .horizontal)
    static let showCodeInWindow = Key<Bool>("showCodeInWindow", default: true)
    static let wubiCodeTip = Key<Bool>("wubiCodeTip", default: true)
    static let wubiAutoCommit = Key<Bool>("wubiAutoCommit", default: false)
    static let wubiFifthCommit = Key<Bool>("wubiFifthCommit", default: false)
    static let candidateHintMode = Key<CandidateHintMode>("candidateHintMode", default: .wubiCode)
    static let candidateCount = Key<Int>("candidateCount", default: 5)
    static let extraCandidateSelectKeys = Key<ExtraCandidateSelectKeys>("extraCandidateSelectKeys", default: .semicolonQuote)
    static let codeMode = Key<CodeMode>("codeMode", default: CodeMode.wubiPinyin)
    static let disableEnMode = Key<Bool>("diableEnMode", default: false)
    static let disableTempEnMode = Key<Bool>("disableTempEnMode", default: false)
    static let toggleInputModeKey = Key<ModifierKey>("toggleInputModeKey", default: .shift)
    static let inputModeTipWindowType = Key<InputModeTipWindowType>("inputModeTipWindowType", default: .centerScreen)
    static let showInputModeStatus = Key<Bool>("showInputModeStatus", default: true)
    static let themeConfig = Key<ThemeConfig>("themeConfig", default: defaultThemeConfig)
    static let importedThemeConfig = Key<ThemeConfig?>("importedThemeConfig", default: nil)
    static let importedThemeConfigs = Key<[ThemeConfig]>("importedThemeConfigs", default: [])
    static let keepAppInputMode = Key<Bool>("keepAppInputMode", default: true)
    static let keepAppInputMode_keys = Key<[String]>("keepAppInputMode_keys", default: [])
    static let keepAppInputMode_cache = Key<[String: InputMode]>("keepAppInputMode_cache", default: [:])
    static let appInputModeTipShowTime = Key<AppInputModeTipShowTime>("appInputModeTipShowTime", default: .onlyChanged)
    static let appSettings = Key<[String: ApplicationSettingItem]>("AppSettings", default: [:])
    static let punctuationMode = Key<PunctuationMode>("punctuationMode", default: .zhhans)
    static let punctuationMappingType = Key<PunctuationMappingType>("punctuationMappingType", default: .default)
    static let punctuationCustomMapping = Key<[String: PunctuationMapping]>(
        "punctuationCustomMapping",
        default: defaultPunctuationMapping
    )
    static let enableDotAfterNumber = Key<Bool>("enableDotAfterNumber", default: true)
    static let enableColonAfterNumber = Key<Bool>("enableColonAfterNumber", default: true)
    static let enablePunctuationAutoPair = Key<Bool>("enablePunctuationAutoPair", default: true)
    static let enableWhitespaceBetweenZhEn = Key<Bool>("enableWhitespaceBetweenZhEn", default: true)
    static let wbTablePath = Key<String>("wbTableURL", default: Bundle.main.resourceURL?.appendingPathComponent("wb_table.txt").path ?? "")
    static let pyTablePath = Key<String>("pyTableURL", default: Bundle.main.resourceURL?.appendingPathComponent("py_table.txt").path ?? "")
    static let wbSpellPath = Key<String>("wbSpellPath", default: Bundle.main.resourceURL?.appendingPathComponent("wubi86_spelling.txt").path ?? "")
    static let enableGBK = Key<Bool>("enableGBK", default: true)
    static let enableEmoji = Key<Bool>("enableEmoji", default: false)
    static let enableExactMatch = Key<Bool>("enableExactMatch", default: false)
    static let enableStatistics = Key<Bool>("enableStatistics", default: true)
    static let celebrationEffect = Key<CelebrationEffectType>("celebrationEffect", default: .none)
    static let quickCombineShortcut = Key<StoredInputShortcut>(
        "quickCombineShortcut",
        default: .init(active: .defaultQuickCombine)
    )
    static let pinCandidateShortcut = Key<StoredDigitInputShortcut>(
        "pinCandidateShortcut",
        default: .init(active: .defaultPinCandidate)
    )
    static let deleteCandidateShortcut = Key<StoredDigitInputShortcut>(
        "deleteCandidateShortcut",
        default: .init(active: .defaultDeleteCandidate)
    )
}
