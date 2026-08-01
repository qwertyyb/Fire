//
//  InputContext.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//

import Foundation
import Defaults

struct InputContext {
    var original: String = ""
    var candidates: [Candidate] = []
    var hasNext: Bool = false
    var curPage: Int = 1
    var selectedIndex: Int = 0
    // 待二次确认删除的候选词，非 nil 时候选窗处于删除确认态
    var pendingDeleteCandidate: Candidate?
    // 组词模式下当前组合的字数，非 nil 时处于"快速加词"组词态
    var combineCount: Int?
    var lastInputIsNumber: Bool = false
    var lastInputText: String = ""
    
    var subState: InputSubState.Type?
    
    var window = CandidatesWindow.shared
    
    var disableTempEnMode = Defaults[.disableTempEnMode]
    
    mutating func setOriginal(_ newVal: String) {
        self.original = newVal
    }
    
    mutating func exitSubState() {
        self.subState = nil
    }
    
    mutating func insertText(_ text: String) {
        
    }
}

