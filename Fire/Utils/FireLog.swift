//
//  FireLog.swift
//  Fire
//

import OSLog

enum FireLog {
    private static let subsystem = "com.qwertyyb.inputmethod.Fire"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let input = Logger(subsystem: subsystem, category: "Input")
    static let dict = Logger(subsystem: subsystem, category: "Dict")
    static let statistics = Logger(subsystem: subsystem, category: "Statistics")
    static let theme = Logger(subsystem: subsystem, category: "Theme")
    static let utils = Logger(subsystem: subsystem, category: "Utils")
}
