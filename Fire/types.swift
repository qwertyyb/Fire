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

enum InputModeSetting: String, Codable {
    case zhhans
    case enUS
    case recentUsed
}

protocol ToastWindowProtocol {
    func show(_ text: String, position: NSPoint)
}
