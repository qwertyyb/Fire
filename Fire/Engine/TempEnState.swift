//
//  TempEnState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//  临时英文模式：触发符、状态判断与 placeholder 候选生成。
//

import Foundation
import Carbon

struct TempEnState: InputState {
    
    static let trigger: String = ";"
    
    static func shouldEnter(_ event: KeyInput, context: InputContext) -> Bool {
        return context.origin.isEmpty && event.characters == Self.trigger
    }
    
    var store: any EngineStore
    
    init(store: any EngineStore) {
        self.store = store
    }
    
    mutating func handle(_ event: KeyInput, context: inout InputContext, exitState: () -> Void) -> Bool? {
        var origin = context.origin
        if event.characters == Self.trigger && origin == Self.trigger {
            // 连续两次按了 trigger 键，应当退出临时英文模式，并把trigger转为全角输出
            if let result = PunctuationConversion.shared.conversion(origin) {
                context.commit(result)
            }
            exitState()
            return false
        }
        if event.keyCode == kVK_Return  {
            // 回车键，把除了第一个触发码外的字符上屏，并退出临时英文模式
            let text = String(origin.dropFirst())
            store.recentCommittedTexts.append(text)
            context.commit(text)
            exitState()
            return true
        }
        if EngineUtils.isEscapeKey(event) {
            // Esc 键，清空原码并退出临时英文模式
            origin = ""
        } else if EngineUtils.isDeleteKey(event) {
            origin = String(origin.dropLast())
        } else if let char = event.characters {
            origin += char
        }
        context.origin = origin
        if origin.isEmpty {
            exitState()
            return true
        }
        
        context.candidates = [Candidate(code: context.origin, text: "", type: .placeholder, label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")]
        context.curPage = 1
        context.hasNext = false
        return true
    }
    
    func didEnter(_ context: inout InputContext) {
        context.origin = Self.trigger
        context.candidates = [Candidate(code: context.origin, text: "", type: .placeholder, label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")]
        context.curPage = 1
        context.hasNext = false
    }
    
    func willExit(_ context: inout InputContext) {
        context.origin = ""
        context.curPage = 1
        context.candidates = []
    }
}
