//
//  InputState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//

enum HandleResult {
    case end(Bool) // 短路结束
    case exitEnd(Bool) // 退出并结束
}

enum InputStates {
    case start // 初始状态
    case end(Bool) // 结束状态
    case composing // 中文输入默认状态，组词
    case deleteCandidate(Candidate) // 删除候选词状态
    case combine    // 组词状态
    case tempEn     // 临时英文模式
}

protocol InputState {
//    static func canEnter(_ event: KeyInput, context: inout any InputContext) -> Bool
    // 返回nil继续维持当前状态，否则请求流转到下个状态
    mutating func handle(_ event: KeyInput, context: inout any InputContext, exitState: () -> Void) -> Bool?
    
    mutating func didEnter(_ context: inout any InputContext)
    
    mutating func willExit(_ context: inout any InputContext)
}
