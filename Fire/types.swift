//
//  types.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Defaults
import SwiftUI

internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum CandidatesDirection: Int, Decodable, Encodable, Defaults.Serializable {
    case vertical
    case horizontal
}

enum ExtraCandidateSelectKeys: String, Codable, Defaults.Serializable {
    case disabled
    case semicolonQuote
    case commaPeriod
}

// 拆字/拼音方案枚举：决定候选中显示哪种方案的拆字字根和拼音
enum SpellingScheme: String, Codable, Defaults.Serializable {
    case wubi86  // 五笔86版
    case wubi98  // 五笔98版
    case wubi06  // 五笔06版（新世纪）
}

// 候选词提示模式：控制候选词旁显示什么额外信息
enum CandidateHintMode: String, Codable, Defaults.Serializable {
    case none       // 不提示
    case wubiCode   // 显示五笔编码（如 ~fg）
    case spelling   // 显示拆字字根（如 〈氵工〉）
    case pinyin     // 显示拼音
}

enum InputModeTipWindowType: Int, Decodable, Encodable, Defaults.Serializable {
    case followInput
    case centerScreen
    case none
}

// 应用切换时，显示输入模式框时机
enum AppInputModeTipShowTime: Int, Decodable, Encodable, Defaults.Serializable {
    case onlyChanged // 仅在切换后的输入模式与之前不一致时显示
    case always // 应用切换即显示，无论有没有变化
    case none // 不显示
}

enum ModifierKey: String, Codable, Defaults.Serializable {
  case shift
  case leftShift
  case rightShift
  case control
  case command
  case option
  case function
}

/// 热键可用的修饰键（不包含 shift/fn/leftShift/rightShift，因为这些不适合作为主修饰键）
enum HotkeyModifier: String, Codable, Defaults.Serializable, CaseIterable {
    case control
    case option
    case command

    var nsModifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .command: return .command
        }
    }

    var cgEventFlag: CGEventFlags {
        switch self {
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .command: return .maskCommand
        }
    }
}

class ApplicationSettingItem: ObservableObject, Codable, Identifiable, Defaults.Serializable {
    var id: String { bundleIdentifier }

    @Published var bundleIdentifier: String = ""

    @Published var inputModeSetting: InputModeSetting = InputModeSetting.recentUsed {
        didSet {
            self.objectWillChange.send()
        }
    }

    var createdTimestamp: Int = 0

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case inputModeSetting
        case createdTimestamp
    }

    init(bundleId: String, inputMs: InputModeSetting) {
        bundleIdentifier = bundleId
        inputModeSetting = inputMs
        createdTimestamp = Int(Date().timeIntervalSince1970)
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try values.decode(String.self, forKey: .bundleIdentifier)
        inputModeSetting = try values.decode(InputModeSetting.self, forKey: .inputModeSetting)
        createdTimestamp = try values.decode(Int.self, forKey: .createdTimestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(inputModeSetting, forKey: .inputModeSetting)
        try container.encode(createdTimestamp, forKey: .createdTimestamp)
    }
}

// MARK: - Defaults 键值定义


enum InputMode: String, Defaults.Serializable {
    case zhhans
    case enUS
}

enum InputModeSetting: String, Codable {
    case zhhans
    case enUS
    case recentUsed
}

enum CandidateType: String, CaseIterable {
    case wb // 五笔
    case py // 拼音
    case user // 用户词库
    case placeholder // 运行时类型，无匹配时表示占位
    case unknown // 未知类型，用于安全解析数据库记录
}

struct Candidate: Hashable {
    let code: String
    let text: String
    let type: CandidateType
    let label: String
    // 拆字字根（如 〈氵工〉）
    let spelling: String?
    // 拼音
    let pinyin: String?

    init(code: String, text: String, type: CandidateType, label: String? = nil, spelling: String? = nil, pinyin: String? = nil) {
        self.code = code
        self.text = text
        self.type = type
        self.label = label ?? text
        self.spelling = spelling
        self.pinyin = pinyin
    }
}

enum CodeMode: Int, CaseIterable, Decodable, Encodable, Defaults.Serializable {
    case wubi
    case pinyin
    case wubiPinyin
}


protocol ToastWindowProtocol {
    func show(_ text: String, position: NSPoint)
}
