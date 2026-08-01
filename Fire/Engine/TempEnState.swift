//
//  TempEnState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//  临时英文模式：触发符、状态判断与 placeholder 候选生成。
//

import Foundation
import Carbon

enum TempEnSubState: InputSubState {
    static let trigger: String = ";"
    
    static func tryEnter(_ event: KeyInput, context: inout InputContext) -> Bool {
        let isTrigger = event.characters == trigger
        let triggered = !context.disableTempEnMode && context.original.isEmpty && isTrigger
        
        let candidatesData = (
            list: [Candidate(code: context.original, text: "", type: .placeholder, label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")],
            hasPrev: false,
            hasNext: false
        )
        context.window.setState(
            original: context.original,
            candidatesData: candidatesData,
            selectedIndex: 0
        )
        
        return triggered
    }
    
    static func handle(_ event: KeyInput, context: inout InputContext) -> Bool {
        var original = context.original
        if event.characters == trigger && original == trigger {
            // 连续两次按了 trigger 键，应当退出临时英文模式，并把键交由后面的逻辑处理
            context.exitSubState()
            return false
        }
        if event.keyCode == kVK_Return  {
            // 回车键，把除了第一个触发码外的字符上屏，并退出临时英文模式
            context.insertText(String(original.dropFirst()))
            context.exitSubState()
            return false
        }
        if EngineUtils.isEscapeKey(event) {
            // Esc 键，清空原码并退出临时英文模式
            original = ""
        } else if EngineUtils.isDeleteKey(event) {
            original = String(original.dropLast())
        } else if event.keyCode == kVK_Return  {
            context.insertText(String(original.dropFirst()))
            context.exitSubState()
            return false
        } else if let char = event.characters {
            original += char
        }
        context.setOriginal(original)
        if original.isEmpty {
            context.window.close()
            context.exitSubState()
            return true
        } else {
            let candidatesData = (
                list: [Candidate(code: context.original, text: "", type: .placeholder, label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")],
                hasPrev: false,
                hasNext: false
            )
            context.window.setState(
                original: context.original,
                candidatesData: candidatesData,
                selectedIndex: 0
            )
            return true
        }
    }
}
