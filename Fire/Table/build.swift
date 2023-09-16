//
//  build.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/24.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Defaults

func getDatabaseURL () -> URL {
    guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return URL(fileURLWithPath: "")
    }
    let appDir = supportDir.appendingPathComponent(Bundle.main.bundleIdentifier!)
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
    print("update dict with new")
    var bkURL = getDatabaseURL()
    bkURL.appendPathExtension("bk")

    let dbURL = getDatabaseURL()

    try? FileManager.default.removeItem(at: bkURL)
    try? FileManager.default.moveItem(at: dbURL, to: bkURL)
    try? FileManager.default.moveItem(at: getDatabaseURL().appendingPathExtension("ing"), to: dbURL)
}

func buildDict() {
    beforeBuildDict()

    let wbPath = Defaults[.wbTablePath]
    let pyPath = Defaults[.pyTablePath]

    let wb = buildTable(txtPath: wbPath, tableName: "wb_dict")
    let py = buildTable(txtPath: pyPath, tableName: "py_dict")
    let cb = combineTableList(wbTable: "wb_dict", pyTable: "py_dict")

    print(wb, py, cb)
    if wb && py && cb {
        afterBuildDict()
    }
}

func hasDict() -> Bool {
    return FileManager.default.fileExists(atPath: getDatabaseURL().path)
}
