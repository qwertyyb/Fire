//
//  PunctuationConversion.swift
//  Fire
//
//  Created by 杨永榜 on 2023/10/26.
//

import Foundation
import Defaults

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
    
    // 转换单双引号
    // 基本思路: 第一次按引号输入左引号，第二次按输入右引号
    private func transformQuoteResult(_ result: String) -> String {
        if !quoteCount.keys.contains(result) {
            return result
        }
        let resultMap = [
            "‘": "’",
            "“": "”"
        ]
        quoteCount[result] = (quoteCount[result]! + 1) % 2
        if quoteCount[result] == 0 {
            return resultMap[result]!
        }
        return result
    }
    
    // 转换方括号
    // 基本思路: 第一次按{输出「，第二次按{输出『，按}时，以左括号为优先进行匹配
    private func transformSquareBrackets(_ result: String) -> String {
        if !squareBracketsCount.keys.contains(result) {
            return result
        }
        let resultMap = [
            "「": "『",
            "」": "』"
        ]
        
        squareBracketsCount[result] = (squareBracketsCount[result]! + 1) % 2
        if result == "「" {
            squareBracketsCount["」"] = (squareBracketsCount[result]! + 1) % 2
        }
        if squareBracketsCount[result] == 0 {
            return resultMap[result]!
        }
        return result
    }
    
    private func transformResult(_ result: String) -> String {
        return transformQuoteResult(transformSquareBrackets(result))
    }
    
    func conversion(_ origin: String) -> String? {
        let isPunctuation = punctuation.keys.contains(origin)
        if !isPunctuation {
            return nil
        }
        let mode = Defaults[.punctuationMode]
        if mode == .enUs {
            return origin
        }
        if mode == .zhhans {
            return punctuation[origin] == nil ? nil : transformResult(punctuation[origin]!)
        }
        if mode == .custom {
            return Defaults[.customPunctuationSettings][origin]
        }
        return nil
    }
    
    static let shared = PunctuationConversion()
}
