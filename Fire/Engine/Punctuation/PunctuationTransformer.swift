//
//  PunctuationTransformer.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/7.
//

import Defaults

enum PunctuationMapping: Codable, Equatable, Defaults.Serializable {
    case commit(String)
    case candidates([String])
    case pair(left: String, right: String)

    enum Kind: String, CaseIterable, Identifiable {
        case commit
        case candidates
        case pair

        var id: String { rawValue }

        var label: String {
            switch self {
            case .commit: return "上屏"
            case .candidates: return "选择"
            case .pair: return "成对"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .commit: return .commit
        case .candidates: return .candidates
        case .pair: return .pair
        }
    }

    /// 设置界面与旧版 Conversion 协议使用的首选输出文本
    var primaryOutput: String {
        switch self {
        case .commit(let text):
            return text
        case .candidates(let list):
            return list.first ?? ""
        case .pair(let left, _):
            return left
        }
    }
}

enum PunctuationMappingType: String, Codable, Defaults.Serializable {
    case `default`
    case custom
}

protocol PunctuationTransformer {
    func transform(_ origin: String) -> PunctuationMapping?
}
