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
    // 左引号暂存栈
    private var parisPunctuationStack: [String] = []
    private let MAX_STACK_SIZE = 30 // 暂存栈大小，防止随着使用出现内存上涨
    
    private func transformResult(_ result: String) -> String {
        let resultMap = [
            "‘": "’",
            "“": "”"
        ]
        // 存在需要待匹配的左侧引号，并且当前输出和待匹配的引号一致，把结果转为对应的右侧引号
        if resultMap.keys.contains(result) && result == parisPunctuationStack.last {
            _ = parisPunctuationStack.popLast()
            return resultMap[result] ?? result
        }
        // 没有待匹配的引号，并且输入了左侧引号，存入待匹配区
        if resultMap.keys.contains(result) {
            parisPunctuationStack.append(result)
            if parisPunctuationStack.count > MAX_STACK_SIZE {
                parisPunctuationStack.removeFirst()
            }
            return result
        }
        return result
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
