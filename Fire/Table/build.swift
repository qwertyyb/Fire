//
//  build.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/24.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Defaults

private let dictSchemaVersion: Int32 = 3

/// 安全读取可为 NULL 的 SQLite 文本列
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

// MARK: - Schema

func hasDict() -> Bool {
    return FileManager.default.fileExists(atPath: getDatabaseURL().path)
}

private func dbHasColumn(_ db: OpaquePointer?, table: String, column: String) -> Bool {
    let sql = "pragma table_info(\(table))"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    var found = false
    while sqlite3_step(stmt) == SQLITE_ROW {
        if let name = columnText(stmt, 1), name == column {
            found = true
            break
        }
    }
    sqlite3_finalize(stmt)
    return found
}

private func dbHasTable(_ db: OpaquePointer?, table: String) -> Bool {
    let sql = "select count(*) from sqlite_master where type = 'table' and name = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
    var found = false
    if sqlite3_step(stmt) == SQLITE_ROW {
        found = sqlite3_column_int(stmt, 0) > 0
    }
    sqlite3_finalize(stmt)
    return found
}

func isDictSchemaCurrent() -> Bool {
    let path = getDatabaseURL().path
    guard FileManager.default.fileExists(atPath: path) else { return false }
    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
    defer { sqlite3_close(db) }
    guard dbHasColumn(db, table: "wb_py_dict", column: "spell"),
          dbHasTable(db, table: "blocked_words") else {
        return false
    }
    var version: Int32 = 0
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, "pragma user_version", -1, &stmt, nil) == SQLITE_OK,
       sqlite3_step(stmt) == SQLITE_ROW {
        version = sqlite3_column_int(stmt, 0)
    }
    sqlite3_finalize(stmt)
    return version >= dictSchemaVersion
}

private func setDictSchemaVersion(_ version: Int32, at path: String) -> Bool {
    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return false }
    defer { sqlite3_close(db) }
    let sql = "pragma user_version = \(version)"
    return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
}

private func ensureBlockedWordsTable(at path: String) -> Bool {
    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return false }
    defer { sqlite3_close(db) }
    guard sqlite3_exec(db, "create table if not exists blocked_words (text text primary key)", nil, nil, nil) == SQLITE_OK else {
        return false
    }
    // text 为 PRIMARY KEY 时 SQLite 自带索引；显式建索引供查询优化器选用
    return sqlite3_exec(db, "create index if not exists blocked_words_text_index on blocked_words(text)", nil, nil, nil) == SQLITE_OK
}

// MARK: - Migration

private func migrateBlockedWords(oldPath: String, newPath: String) -> Bool {
    guard FileManager.default.fileExists(atPath: oldPath) else {
        print("[migrateBlockedWords] no old db")
        return true
    }

    var oldDb: OpaquePointer?
    guard sqlite3_open_v2(oldPath, &oldDb, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        print("[migrateBlockedWords] cannot open old db")
        return false
    }

    guard dbHasTable(oldDb, table: "blocked_words") else {
        sqlite3_close(oldDb)
        print("[migrateBlockedWords] no blocked_words in old db, skip")
        return true
    }

    var selectStmt: OpaquePointer?
    guard sqlite3_prepare_v2(oldDb, "select text from blocked_words", -1, &selectStmt, nil) == SQLITE_OK else {
        sqlite3_close(oldDb)
        return false
    }

    var words: [String] = []
    while sqlite3_step(selectStmt) == SQLITE_ROW {
        if let text = columnText(selectStmt, 0) {
            words.append(text)
        }
    }
    sqlite3_finalize(selectStmt)
    sqlite3_close(oldDb)

    guard !words.isEmpty else {
        print("[migrateBlockedWords] empty blocked_words")
        return true
    }

    var newDb: OpaquePointer?
    guard sqlite3_open_v2(newPath, &newDb, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        print("[migrateBlockedWords] cannot open new db")
        return false
    }

    sqlite3_exec(newDb, "BEGIN TRANSACTION", nil, nil, nil)
    let insertSql = "insert or ignore into blocked_words(text) values(?)"
    var ins: OpaquePointer?
    guard sqlite3_prepare_v2(newDb, insertSql, -1, &ins, nil) == SQLITE_OK else {
        sqlite3_close(newDb)
        return false
    }
    for word in words {
        sqlite3_reset(ins)
        sqlite3_bind_text(ins, 1, word, -1, SQLITE_TRANSIENT)
        sqlite3_step(ins)
    }
    sqlite3_finalize(ins)
    sqlite3_exec(newDb, "delete from wb_py_dict where type = 'blocked'", nil, nil, nil)
    sqlite3_exec(newDb, "COMMIT", nil, nil, nil)
    sqlite3_close(newDb)
    print("[migrateBlockedWords] migrated \(words.count) words")
    return true
}

/// 从旧库迁移用户词：只读 wbcode/text/query，在新库重新分配 id 并填充拆字
private func migrateUserDict(oldPath: String, newPath: String) -> Bool {
    guard FileManager.default.fileExists(atPath: oldPath) else {
        print("[migrateUserDict] no old db")
        return true
    }

    var oldDb: OpaquePointer?
    guard sqlite3_open_v2(oldPath, &oldDb, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        print("[migrateUserDict] cannot open old db")
        return false
    }

    let selectSql = "select wbcode, text, query from wb_py_dict where type = 'user'"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(oldDb, selectSql, -1, &stmt, nil) == SQLITE_OK else {
        sqlite3_close(oldDb)
        print("[migrateUserDict] select failed (old schema may lack user rows)")
        return true
    }

    struct UserRow { let wbcode: String; let text: String; let query: String }
    var rows: [UserRow] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        guard let wbcode = columnText(stmt, 0),
              let text = columnText(stmt, 1),
              let query = columnText(stmt, 2) else { continue }
        rows.append(UserRow(wbcode: wbcode, text: text, query: query))
    }
    sqlite3_finalize(stmt)
    sqlite3_close(oldDb)

    guard !rows.isEmpty else {
        print("[migrateUserDict] no user rows")
        return true
    }

    var newDb: OpaquePointer?
    guard sqlite3_open_v2(newPath, &newDb, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        print("[migrateUserDict] cannot open new db")
        return false
    }

    var minId: Int32 = 0
    var minStmt: OpaquePointer?
    if sqlite3_prepare_v2(newDb, "select min(id) from wb_py_dict", -1, &minStmt, nil) == SQLITE_OK,
       sqlite3_step(minStmt) == SQLITE_ROW {
        minId = sqlite3_column_int(minStmt, 0)
    }
    sqlite3_finalize(minStmt)

    let insertSql = """
        insert into wb_py_dict(id, wbcode, text, type, query, spell, pinyin, is_gb2312)
        values(?1, ?2, ?3, 'user', ?4,
            (select spell from wb_py_dict where text = ?5 and spell is not null limit 1),
            (select pinyin from wb_py_dict where text = ?5 and pinyin is not null limit 1),
            1)
    """

    sqlite3_exec(newDb, "BEGIN TRANSACTION", nil, nil, nil)
    var ins: OpaquePointer?
    guard sqlite3_prepare_v2(newDb, insertSql, -1, &ins, nil) == SQLITE_OK else {
        sqlite3_close(newDb)
        return false
    }

    for (n, row) in rows.enumerated() {
        let id = minId - Int32(rows.count) + Int32(n)
        sqlite3_reset(ins)
        sqlite3_clear_bindings(ins)
        sqlite3_bind_int(ins, 1, id)
        sqlite3_bind_text(ins, 2, row.wbcode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(ins, 3, row.text, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(ins, 4, row.wbcode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(ins, 5, row.text, -1, SQLITE_TRANSIENT)
        if sqlite3_step(ins) != SQLITE_DONE {
            print("[migrateUserDict] insert failed for \(row.text)")
        }
    }
    sqlite3_finalize(ins)

    var multiCharTexts = Set<String>()
    for row in rows where DictGlyphFill.codePoints(row.text).count > 1 {
        multiCharTexts.insert(row.text)
    }
    for text in multiCharTexts {
        DictGlyphFill.fillCompoundGlyphs(db: newDb, text: text, skipIfExists: true)
    }

    sqlite3_exec(newDb, "COMMIT", nil, nil, nil)
    sqlite3_close(newDb)
    print("[migrateUserDict] migrated \(rows.count) user entries")
    return true
}

@discardableResult
func buildDict() -> Bool {
    beforeBuildDict()

    let wbPath = Defaults[.wbTablePath]
    let pyPath = Defaults[.pyTablePath]
    let newPath = getDatabaseURL().appendingPathExtension("ing").path
    let oldPath = getDatabaseURL().path

    let resourceURL = Bundle.main.resourceURL
    let wbSpellPath = Defaults[.wbSpellPath]
    let pinyinSpellPath = resourceURL?.appendingPathComponent("pinyin_spell.txt").path
    let emojiPath = resourceURL?.appendingPathComponent("emoji_table.txt").path

    let built = DictBuilder.build(
        wbPath: wbPath,
        pyPath: pyPath,
        dbPath: newPath,
        wbSpellPath: wbSpellPath,
        pinyinSpellPath: pinyinSpellPath,
        emojiPath: emojiPath
    )
    guard built else {
        print("build failed")
        print("[buildDict] wbPath=\(wbPath) pyPath=\(pyPath)")
        if !FileManager.default.fileExists(atPath: pyPath) {
            print("[buildDict] 拼音词库文件不存在或路径错误: \(pyPath)")
        }
        return false
    }

    guard ensureBlockedWordsTable(at: newPath) else {
        print("[buildDict] ensureBlockedWordsTable failed")
        return false
    }
    guard migrateBlockedWords(oldPath: oldPath, newPath: newPath) else {
        print("[buildDict] migrateBlockedWords failed")
        return false
    }
    guard migrateUserDict(oldPath: oldPath, newPath: newPath) else {
        print("[buildDict] migrateUserDict failed")
        return false
    }

    afterBuildDict()

    guard setDictSchemaVersion(dictSchemaVersion, at: getDatabaseURL().path) else {
        print("[buildDict] setDictSchemaVersion failed")
        return false
    }

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
}
