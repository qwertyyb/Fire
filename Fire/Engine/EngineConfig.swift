//
//  EngineConfig.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/4.
//

import Defaults
import Carbon

protocol EngineConfig {
    /** 禁用英文输入模式 */
    var disableEnMode: Bool { get }
    
    /** 切换中英文模式的按键 */
    var toggleInputModeKey: ModifierKey { get }
    
    /** 候选词方向  */
    var candidatesDirection: CandidatesDirection { get }

    /** 数字后句号转为小数点 */
    var enableDotAfterNumber: Bool { get }

    /** 数字后冒号自动转为半角 */
    var enableColonAfterNumber: Bool { get }
    
    /** 第五码自动上屏首候选词 */
    var wubiFifthCommit: Bool { get }
    
    /** 四码唯一自动上屏 */
    var wubiAutoCommit: Bool { get }
    
    /** 编码方案 */
    var codeMode: CodeMode { get }

    /** 额外的候选词键 */
    var extraCandidateSelectKeys: ExtraCandidateSelectKeys { get }
    
    /** 禁用临时英文模式 */
    var disableTempEnMode: Bool { get }
}

enum CandidatesDirection: Int, Decodable, Encodable, Defaults.Serializable {
    case vertical
    case horizontal
}

enum CodeMode: Int, CaseIterable, Decodable, Encodable, Defaults.Serializable {
    case wubi
    case pinyin
    case wubiPinyin
}

enum ExtraCandidateSelectKeys: String, Codable, Defaults.Serializable {
    case disabled
    case semicolonQuote
    case commaPeriod
}

enum ModifierKey: String, Codable, Defaults.Serializable {
    case shift
    case leftShift
    case rightShift
    case control
    case command
    case option
    case function
    
    func keyCodes() -> [Int] {
        switch self {
        case .shift:
            return [kVK_Shift, kVK_RightShift]
        case .leftShift:
            return [kVK_Shift]
        case .rightShift:
            return [kVK_RightShift]
        case .command:
            return [kVK_Command, kVK_RightCommand]
        case .control:
            return [kVK_Control, kVK_RightControl]
        case .option:
            return [kVK_Option, kVK_RightOption]
        case .function:
            return [kVK_Function]
        }
    }
}
