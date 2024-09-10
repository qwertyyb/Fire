//
//  MainAppXPCService.swift
//  Fire
//
//  Created by 杨永榜 on 2024/9/10.
//

import Foundation
import FireXPCService

public class MainAppXPCService: NSObject, MainAppXPCServiceProtocol {
    
    public func check(with reply: @escaping (Int) -> Void) {
        reply(0)
    }
    
    public func getMode(with reply: @escaping (String) -> Void) {
        reply(Fire.shared.inputMode.rawValue)
    }
    
    public func setMode(inputMode: String, showTip: Bool) {
        let mode = InputMode(rawValue: inputMode)
        Fire.shared.toggleInputMode(mode, showTip: showTip)
    }
    
}
