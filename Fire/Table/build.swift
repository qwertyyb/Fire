//
//  build.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/24.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Defaults

/// 安全读取可为 NULL 的 SQLite 文本列
/// 注：TableBuilder 目标不含 Utils.swift，需本地定义
private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
    return String(cString: cStr)
}

func getDatabaseURL () -> URL {
    guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return URL(fileURLWithPath: "")
    }
    let appDir = supportDir.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire")
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
    print("execTableBuilder: \(arguments.joined(separator: " "))")

    let pipe = Pipe()
    task.standardError = pipe

    task.launch()

    // 60秒超时，防止 TableBuilder 子进程卡死导致首选项窗口无响应
    let timeout = DispatchTime.now() + .seconds(60)
    DispatchQueue.global().asyncAfter(deadline: timeout) {
        if task.isRunning {
            print("execTableBuilder timeout, terminating")
            task.terminate()
        }
    }

    task.waitUntilExit()

    let errData = pipe.fileHandleForReading.readDataToEndOfFile()
    if let errStr = String(data: errData, encoding: .utf8), !errStr.isEmpty {
        print("TableBuilder stderr: \(errStr)")
    }

    if task.terminationStatus == .zero {
        print("exec successfully")
        return true
    } else {
        print("exec fail, status: \(task.terminationStatus)")
        return false
    }
}

func buildTable(txtPath: String, tableName: String = "wb_dict") -> Bool {
    // 校验码表文件存在，避免传递无效路径给子进程
    guard FileManager.default.fileExists(atPath: txtPath) else {
        print("buildTable: file not found: \(txtPath)")
        return false
    }
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")
    return execTableBuilder(arguments: [
        "--create-dict",
        txtPath,
        tableName,
        dbTempURL.path
    ])
}


// 将 combine-dict 和 merge-spelling 合并为一次 --build-all 子进程调用
// 减少一次 Process 启动开销，码表构建速度提升约 1 倍
func buildCombined(wbTable: String = "wb_dict", pyTable: String = "py_dict") -> Bool {
    var dbTempURL = getDatabaseURL()
    dbTempURL.appendPathExtension("ing")

    guard let resourceURL = Bundle.main.resourceURL else { return false }
    let s86 = resourceURL.appendingPathComponent("wubi86_spelling.txt").path
    let s98 = resourceURL.appendingPathComponent("wubi98_spelling.txt").path
    let s06 = resourceURL.appendingPathComponent("wubi06_spelling.txt").path

    guard FileManager.default.fileExists(atPath: s86),
          FileManager.default.fileExists(atPath: s98),
          FileManager.default.fileExists(atPath: s06) else {
        // 拼写文件不存在，回退到普通 combine
        print("spelling files not found, use separate combine")
        return execTableBuilder(arguments: [
            "--combine-dict", dbTempURL.path, wbTable, pyTable
        ])
    }

    return execTableBuilder(arguments: [
        "--build-all", dbTempURL.path, wbTable, pyTable, s86, s98, s06
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

@discardableResult
func buildDict() -> Bool {
    beforeBuildDict()

    let wbPath = Defaults[.wbTablePath]
    let pyPath = Defaults[.pyTablePath]

    let wb = buildTable(txtPath: wbPath, tableName: "wb_dict")
    let py = buildTable(txtPath: pyPath, tableName: "py_dict")
    let cb = buildCombined(wbTable: "wb_dict", pyTable: "py_dict")

    print(wb, py, cb)
    if wb && py && cb {
        // 迁移用户词库到新数据库
        migrateUserDict()
        afterBuildDict()
        // 验证新库：统计 type='wb' 的条目数，确认重建生效
        var countDb: OpaquePointer?
        if sqlite3_open_v2(getDatabaseURL().path, &countDb, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            var countStmt: OpaquePointer?
            if sqlite3_prepare_v2(countDb, "select count(*) from wb_py_dict where type = 'wb' and version is null", -1, &countStmt, nil) == SQLITE_OK,
               sqlite3_step(countStmt) == SQLITE_ROW {
                let wbCount = sqlite3_column_int(countStmt, 0)
                print("[buildDict] new db wb entries: \(wbCount)")
            }
            sqlite3_finalize(countStmt)
            sqlite3_close(countDb)
        }
        return true
    } else {
        print("build failed")
        print("[buildDict] wb=\(wb) py=\(py) cb=\(cb)")
        if !py { print("[buildDict] 拼音词库文件不存在或路径错误: \(Defaults[.pyTablePath])") }
        return false
    }
}

/// 将旧数据库中的用户词库迁移到新构建的数据库
func migrateUserDict() {
    let oldPath = getDatabaseURL().path
    let newPath = getDatabaseURL().appendingPathExtension("ing").path

    guard FileManager.default.fileExists(atPath: oldPath) else {
        print("no old dict to migrate")
        return
    }

    var oldDb: OpaquePointer?
    guard sqlite3_open_v2(oldPath, &oldDb, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        print("migrate: cannot open old db")
        return
    }

    var stmt: OpaquePointer?
    let selectSql = "select id, wbcode, text, query, type, s86, s98, s06, is_gb2312 from wb_py_dict where type in ('user', 'blocked')"
    guard sqlite3_prepare_v2(oldDb, selectSql, -1, &stmt, nil) == SQLITE_OK else {
        sqlite3_close(oldDb)
        return
    }

    var rows: [(id: Int, wbcode: String, text: String, query: String, type: String, s86: String?, s98: String?, s06: String?, is_gb2312: Int)] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        let id = Int(sqlite3_column_int(stmt, 0))
        guard let wbcode = columnText(stmt, 1),
              let text = columnText(stmt, 2),
              let query = columnText(stmt, 3),
              let type = columnText(stmt, 4) else { continue }
        let s86 = columnText(stmt, 5)
        let s98 = columnText(stmt, 6)
        let s06 = columnText(stmt, 7)
        let is_gb2312 = Int(sqlite3_column_int(stmt, 8))
        rows.append((id, wbcode, text, query, type, s86, s98, s06, is_gb2312))
    }
    sqlite3_finalize(stmt)
    sqlite3_close(oldDb)

    guard !rows.isEmpty else { return }

    var newDb: OpaquePointer?
    guard sqlite3_open_v2(newPath, &newDb, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        print("migrate: cannot open new db")
        return
    }

    sqlite3_exec(newDb, "BEGIN TRANSACTION", nil, nil, nil)

    for row in rows {
        let sql = "insert into wb_py_dict(id, wbcode, text, type, query, s86, s98, s06, is_gb2312) values(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)"
        var ins: OpaquePointer?
        guard sqlite3_prepare_v2(newDb, sql, -1, &ins, nil) == SQLITE_OK else { continue }
        sqlite3_bind_int(ins, 1, Int32(row.id))
        sqlite3_bind_text(ins, 2, row.wbcode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(ins, 3, row.text, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(ins, 4, row.type, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(ins, 5, row.query, -1, SQLITE_TRANSIENT)
        if let s86 = row.s86 { sqlite3_bind_text(ins, 6, s86, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(ins, 6) }
        if let s98 = row.s98 { sqlite3_bind_text(ins, 7, s98, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(ins, 7) }
        if let s06 = row.s06 { sqlite3_bind_text(ins, 8, s06, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(ins, 8) }
        sqlite3_bind_int(ins, 9, Int32(row.is_gb2312))
        sqlite3_step(ins)
        sqlite3_finalize(ins)
    }

    sqlite3_exec(newDb, "END TRANSACTION", nil, nil, nil)
    sqlite3_close(newDb)
    print("migrated \(rows.count) user entries")
}

func hasDict() -> Bool {
    return FileManager.default.fileExists(atPath: getDatabaseURL().path)
}
