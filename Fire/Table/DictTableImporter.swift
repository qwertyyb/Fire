//
//  DictTableImporter.swift
//  Fire
//
//  将 Fire 格式码表（编码在前）导入为 wb_dict / py_dict。
//

import Foundation

enum DictTableImporter {
    /// 按空白切分（与 TableBuilder `split` 一致）
    static func splitFields(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in line {
            if ch == " " || ch == "\t" || ch == "\r" || ch == "\n" {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    static func createCodeTextTable(db: OpaquePointer?, tableName: String) -> Bool {
        let sql = """
            create table if not exists \(tableName)(
                id integer primary key autoincrement not null,
                code text not null,
                text text not null
            );
            insert into sqlite_sequence(name, seq) values('\(tableName)', 100000);
            create index if not exists \(tableName)_code_index on \(tableName)(code);
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            print("[DictTableImporter] create table \(tableName) failed: \(errmsg(db))")
            return false
        }
        return true
    }

    /// 导入 Fire 格式：首列 code，后续每列一条 text
    static func importTable(db: OpaquePointer?, txtPath: String, tableName: String) -> Bool {
        guard FileManager.default.fileExists(atPath: txtPath) else {
            print("[DictTableImporter] file not found: \(txtPath)")
            return false
        }
        guard createCodeTextTable(db: db, tableName: tableName) else { return false }

        guard let content = try? String(contentsOfFile: txtPath, encoding: .utf8) else {
            print("[DictTableImporter] cannot read: \(txtPath)")
            return false
        }

        let insertSQL = "insert into \(tableName)(code, text) values(?1, ?2)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            print("[DictTableImporter] prepare insert failed: \(errmsg(db))")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        var count = 0
        for line in content.split(whereSeparator: \.isNewline) {
            let fields = splitFields(String(line))
            guard fields.count >= 2 else { continue }
            let code = fields[0]
            for text in fields.dropFirst() {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, text, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("[DictTableImporter] insert failed: \(errmsg(db))")
                    sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                    return false
                }
                count += 1
            }
        }
        guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
            print("[DictTableImporter] commit failed: \(errmsg(db))")
            return false
        }
        print("[DictTableImporter] \(tableName) imported \(count) rows from \(txtPath)")
        return true
    }

    private static func errmsg(_ db: OpaquePointer?) -> String {
        guard let db = db, let c = sqlite3_errmsg(db) else { return "unknown" }
        return String(cString: c)
    }
}
