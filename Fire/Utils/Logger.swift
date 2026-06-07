//
//  Logger.swift
//  Fire
//
//  Created by qwertyyb on 2026/6/6.
//

import Foundation
import OSLog

extension Logger {
    private static var bundleId: String {
        Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire"
    }
    static let inputController = Logger(subsystem: bundleId, category: "FireInputController")
    
    static let inputServer = Logger(subsystem: bundleId, category: "FireInputServer")
    
    static let performance = Logger(subsystem: bundleId, category: "Performance")
    
    static let dictManager = Logger(subsystem: bundleId, category: "DictManager")
}
