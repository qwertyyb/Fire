//
//  InputState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//

enum HandleResult {
    case stay(Bool) // 事件已消费，保持当前状态不变
    case exit(Bool) // 事件已消费，并退出当前状态
    case transition(_ to: any InputState, output: Bool) // 事件已消费，并转换到新的状态
}

protocol InputState {
//    static func canEnter(_ event: KeyInput, context: inout any InputContext) -> Bool
    // 返回nil继续维持当前状态，否则请求流转到下个状态
    mutating func handle(_ event: KeyInput, context: inout any InputContext) -> HandleResult
    
    mutating func didEnter(_ context: inout any InputContext)
    
    mutating func willExit(_ context: inout any InputContext)
}
