//
//  PunctuationConversion.swift
//  Fire
//
//  Created by qwertyyb on 2023/10/26.
//

import Foundation
import Defaults

/// 全角标点映射表：ASCII 字符 → 中文标点
/// 定义在标点转换模块中而非 types.swift，与使用方放在一起
let punctuation: [String: String] = [
    ",": "，",
    ".": "。",
    "/": "、",
    ";": "；",
    "'": "‘",
    "[": "【",
    "]": "】",
    "`": "`",
    "!": "！",
    "@": "@",
    "#": "#",
    "$": "￥",
    "%": "％",
    "^": "……",
    "&": "&",
    "*": "＊",
    "(": "（",
    ")": "）",
    "-": "-",
    "_": "——",
    "+": "+",
    "=": "=",
    "~": "～",
    "{": "「",
    "\\": "、",
    "|": "｜",
    "}": "」",
    ":": "：",
    "\"": "“",
    "<": "《",
    ">": "》",
    "?": "？"
]

protocol Conversion {
    func conversion(_ origin: String) -> String?
}

class PunctuationConversion: Conversion {
    private var quoteCount = [
        "‘": 0,
        "“": 0,
    ]
    private var squareBracketsCount = [
        "「": 0,
        "」": 0
    ]
    private let pairs: [String: String] = [
        "‘": "’", "“": "”",
        "（": "）", "【": "】",
        "「": "」", "《": "》",
        "『": "』", "〔": "〕",
        
        "'": "'", "\"": "\"",
        "(": ")", "[": "]",
        "{": "}", "<": ">",
    ]
    
    // 转换单双引号
    // 基本思路: 第一次按引号输入左引号，第二次按输入右引号
    private func transformQuoteResult(_ result: String) -> String {
        guard quoteCount[result] != nil else { return result }
        let resultMap = [
            "‘": "’",
            "“": "”"
        ]
        // 使用 ?? 替代 !，避免字典键不存在时崩溃
        quoteCount[result] = ((quoteCount[result] ?? 0) + 1) % 2
        if quoteCount[result] == 0 {
            // resultMap 中必定包含 result，?? 作为安全兜底
            return resultMap[result] ?? result
        }
        return result
    }
    
    // 转换方括号
    // 基本思路: 第一次按{输出「，第二次按{输出『，按}时，以左括号为优先进行匹配
    private func transformSquareBrackets(_ result: String) -> String {
        guard squareBracketsCount[result] != nil else { return result }
        let resultMap = [
            "「": "『",
            "」": "』"
        ]
        
        // 使用 ?? 替代 !，避免字典键不存在时崩溃
        squareBracketsCount[result] = ((squareBracketsCount[result] ?? 0) + 1) % 2
        if result == "「" {
            squareBracketsCount["」"] = ((squareBracketsCount[result] ?? 0) + 1) % 2
        }
        if squareBracketsCount[result] == 0 {
            // resultMap 中必定包含 result，?? 作为安全兜底
            return resultMap[result] ?? result
        }
        return result
    }
    
    private func transformPair(_ result: String) -> String {
        if Defaults[.enablePunctuationAutoPair], let closeStr = pairs[result] {
            return result + closeStr
        }
        return result
    }
    
    private func transformResult(_ result: String) -> String {
        return transformPair(transformQuoteResult(transformSquareBrackets(result)))
    }
    
    func conversion(_ origin: String) -> String? {
        guard punctuation[origin] != nil else { return nil }
        switch Defaults[.punctuationMode] {
        case .enUs:
            return origin
        case .zhhans:
            return punctuation[origin].map { transformResult($0) }
        case .custom:
            guard let mapped = Defaults[.customPunctuationSettings][origin] else { return nil }
            return transformResult(mapped)
        }
    }
    
    func isPair(_ str: String) -> Bool {
        guard str.count == 2,
              let open = str.first,
              let close = str.last else { return false }
        return pairs[String(open)] == String(close)
    }
    
    /// 重置引号/括号配对状态。应在每次输入会话结束时调用，防止跨会话状态错乱。
    func reset() {
        quoteCount = ["‘": 0, "“": 0]
        squareBracketsCount = ["「": 0, "」": 0]
    }
    
    static let shared = PunctuationConversion()
}
