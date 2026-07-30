//
//  TempEnMode.swift
//  Fire
//
//  临时英文模式：触发符、状态判断与 placeholder 候选生成。
//

import Foundation
import Defaults

enum TempEnMode {
    static let trigger: Character = ";"

    /// 当前是否处于临时英文模式
    static func isActive(original: String, disabled: Bool = Defaults[.disableTempEnMode]) -> Bool {
        !disabled && !original.isEmpty && original.first == trigger
    }

    /// 是否应由临时英文 handler 消费该输入字符
    /// - 空输入 + `;`（未禁用）→ 进入
    /// - 已在模式且不是第二个 `;` → 继续追加
    /// - 第二个 `;` → 不消费，交给标点转换输出全角 `；`
    static func shouldConsume(
        original: String,
        input: String,
        disabled: Bool = Defaults[.disableTempEnMode]
    ) -> Bool {
        let isTrigger = input == String(trigger)
        if !disabled && original.isEmpty && isTrigger {
            return true
        }
        if isActive(original: original, disabled: disabled), !isTrigger {
            return true
        }
        return false
    }

    /// 临时英文 placeholder 候选
    static func candidates(query: String) -> [Candidate] {
        let text = query.count == 1 ? query : String(query.suffix(query.count - 1))
        return [Candidate(
            code: query,
            text: text,
            type: .placeholder,
            label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")]
    }
}
