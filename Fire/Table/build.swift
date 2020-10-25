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

func buildTable(txtPath: String, tableName: String = "wb_dict") -> Bool {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    return execTableBuilder(arguments: [
        "--create-dict",
        txtPath,
        tableName,
        dbTempURL.path
    ])
}

func combineTableList(wbTable: String = "wb_dict", pyTable: String = "py_dict") -> Bool {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    return execTableBuilder(arguments: [
        "--combine-dict",
        dbTempURL.path,
        wbTable,
        pyTable
    ])
}

func beforeBuildDict() {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    try? FileManager.default.removeItem(at: dbTempURL)
}

func afterBuildDict() {
    var bkURL = getDatabaseURL()
    bkURL.appendPathExtension("bk")

    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")

    try? FileManager.default.moveItem(at: getDatabaseURL(), to: bkURL)
    try? FileManager.default.moveItem(at: dbTempURL, to: getDatabaseURL())
}

func buildDict() {
    beforeBuildDict()

    let wbPath = Bundle.main.path(forResource: "wb_table", ofType: "txt") ?? ""
    let pyPath = Bundle.main.path(forResource: "py_table", ofType: "txt") ?? ""

    let wb = buildTable(txtPath: wbPath, tableName: "wb_table")
    let py = buildTable(txtPath: pyPath, tableName: "py_table")
    let cb = combineTableList(wbTable: "wb_dict", pyTable: "py_dict")

    print(wb, py, cb)

    afterBuildDict()
}
