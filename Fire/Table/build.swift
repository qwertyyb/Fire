//
//  build.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/24.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Cocoa

func getDatabaseURL () -> URL {
    guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return URL(fileURLWithPath: "")
    }
    guard let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String else {
        return URL(fileURLWithPath: "")
    }
    let appDir = supportDir.appendingPathComponent(appName)
    if !FileManager.default.fileExists(atPath: appDir.path) {
        print("create support directory")
        try? FileManager.default.createDirectory(
            atPath: appDir.path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    let dbURL = appDir.appendingPathComponent("dict.sqlite")
    return dbURL
}

func execTableBuilder(arguments: [String]) -> Bool {
    guard var url = Bundle.main.executableURL else {
        return false
    }
    url.deleteLastPathComponent()
    url = url.appendingPathComponent("TableBuilder")
    let task = Process()
    task.launchPath = url.path
    task.arguments = arguments
    task.launch()
    task.waitUntilExit()
    if task.terminationStatus == .zero {
        print("exec successfully")
        return true
    } else {
        print("exec fail")
        return false
    }
}

func build(txtPath: String, tableName: String = "wb_dict") -> Bool {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    return execTableBuilder(arguments: [
        "--create-dict",
        txtPath,
        tableName,
        dbTempURL.path
    ])
}

func combine(table1: String, table2: String) -> Bool {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    return execTableBuilder(arguments: [
        "--combine-dict",
        dbTempURL.path,
        "wb_dict",
        "py_dict"
    ])
}

func buildWubiDict(txtPath: String?) -> Bool {
    var path = ""
    if txtPath == nil {
        path = Bundle.main.path(forResource: "wb_table", ofType: "txt") ?? ""
    } else {
        path = txtPath!
    }
    return build(txtPath: path, tableName: "wb_dict")
}

func buildPinyinDict(txtPath: String?) -> Bool {
    var path = ""
    if txtPath == nil {
        path = Bundle.main.path(forResource: "py_table", ofType: "txt") ?? ""
    } else {
        path = txtPath!
    }
    return build(txtPath: path, tableName: "py_dict")
}

func buildDict() {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    try? FileManager.default.removeItem(at: dbTempURL)

    let wb = buildWubiDict(txtPath: nil)
    let py = buildPinyinDict(txtPath: nil)
    let cb = combine(table1: "py_dict", table2: "wb_dict")

    print(wb, py, cb)

    var bkURL = getDatabaseURL()
    bkURL.appendPathExtension("bk")
    try? FileManager.default.moveItem(at: getDatabaseURL(), to: bkURL)
    try? FileManager.default.moveItem(at: dbTempURL, to: getDatabaseURL())
}
