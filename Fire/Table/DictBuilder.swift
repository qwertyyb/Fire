//
//  DictBuilder.swift
//  Fire
//
//  进程内构建 dict.sqlite（替代原 TableBuilder 可执行文件）。
//

import Foundation

enum DictBuilder {
    static func build(
        wbPath: String,
        pyPath: String,
        dbPath: String,
        s86Path: String?,
        s98Path: String?,
        s06Path: String?
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: wbPath) else {
            print("[DictBuilder] wb table not found: \(wbPath)")
            return false
        }
        guard FileManager.default.fileExists(atPath: pyPath) else {
            print("[DictBuilder] py table not found: \(pyPath)")
            return false
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("[DictBuilder] cannot open db: \(dbPath)")
            return false
        }
        defer { sqlite3_close(db) }

        // 构建期加速（仅临时 .ing 库）
        sqlite3_exec(db, "PRAGMA journal_mode=MEMORY", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=OFF", nil, nil, nil)

        guard DictTableImporter.importTable(db: db, txtPath: wbPath, tableName: "wb_dict") else {
            return false
        }
        guard DictTableImporter.importTable(db: db, txtPath: pyPath, tableName: "py_dict") else {
            return false
        }
        guard combineWbPy(db: db) else { return false }

        if let s86Path, let s98Path, let s06Path,
           FileManager.default.fileExists(atPath: s86Path),
           FileManager.default.fileExists(atPath: s98Path),
           FileManager.default.fileExists(atPath: s06Path) {
            guard DictSpellingMerge.merge(db: db, s86Path: s86Path, s98Path: s98Path, s06Path: s06Path) else {
                return false
            }
        } else {
            print("[DictBuilder] spelling files missing, skip merge")
        }

        // 用系统编码对所有单字统一标定 is_gb2312（覆盖码表默认值）
        guard CharsetGB2312.updateDatabaseFlags(db: db) else {
            print("[DictBuilder] update GB2312 flags failed")
            return false
        }

        print("[DictBuilder] build complete: \(dbPath)")
        return true
    }

    private static func combineWbPy(db: OpaquePointer?) -> Bool {
        let createTable = """
            create table wb_py_dict (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              wbcode text not null,
              text text not null,
              type text not null,
              query text not null,
              version text default null,
              s86 text default null,
              s98 text default null,
              s06 text default null,
              py86 text default null,
              py98 text default null,
              py06 text default null,
              is_gb2312 integer default 1
            );
            insert into sqlite_sequence(name, seq) values('wb_py_dict', 100000);
            """
        guard sqlite3_exec(db, createTable, nil, nil, nil) == SQLITE_OK else {
            print("[DictBuilder] create wb_py_dict failed: \(errmsg(db))")
            return false
        }

        let fillSQL = """
            insert into wb_py_dict(wbcode, text, type, query)
            select
              code as wbcode,
              text,
              'wb' as type,
              code as query
            from wb_dict;

            insert into wb_py_dict(wbcode, text, type, query)
            select
              wb.code as wbcode,
              py.text as text,
              'py' as type,
              py.code as query
            from
                py_dict py
              inner join
                wb_dict wb
              on py.text = wb.text
            order by py.id;

            create index if not exists query_index on wb_py_dict(query);
            create index if not exists text_index on wb_py_dict(text);
            """
        guard sqlite3_exec(db, fillSQL, nil, nil, nil) == SQLITE_OK else {
            print("[DictBuilder] initialize wb_py_dict failed: \(errmsg(db))")
            return false
        }
        print("[DictBuilder] wb_py_dict combined")
        return true
    }

    private static func errmsg(_ db: OpaquePointer?) -> String {
        guard let db = db, let c = sqlite3_errmsg(db) else { return "unknown" }
        return String(cString: c)
    }
}
