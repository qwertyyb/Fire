//
//  MainAppServiceProtocol.swift
//  Fire
//
//  Created by 杨永榜 on 2024/9/10.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc public protocol MainAppXPCServiceProtocol {
    func check(with reply: @escaping (Int) -> Void)
    func getMode(with reply: @escaping(String) -> Void)
    func setMode(inputMode: String, showTip: Bool)
}

