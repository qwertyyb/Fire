//
//  InputSubState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//

import Foundation

protocol InputSubState {
    static func tryEnter(_ event: KeyInput, context: inout InputContext) -> Bool
    // 返回false退出状态，返回true继续交由状态处理，返回nil，把键交由后面的函数处理
    static func handle(_ event: KeyInput, context: inout InputContext) -> Bool
}
