//
//  DictGlyphFill.swift
//  Fire
//
//  五笔拆字组合逻辑，供 build.swift 迁移与 DictManager 运行时共用。
//

import Foundation

enum DictGlyphFill {
    /// 按 Unicode 标量切分（与 C++ prefix_n 在合法 UTF-8 文本上等价）
    static func codePoints(_ string: String) -> [String] {
        string.unicodeScalars.map(String.init)
    }

    /// 取字符串前 n 个标量（用于 PUA 拆字字根串）
    static func prefixCodePoints(_ string: String, _ count: Int) -> String {
        guard count > 0 else { return "" }
        return String(string.unicodeScalars.prefix(count))
    }

    /// 从码表单字行取三版拆字（优先五笔全码行）
    static func getCharGlyphs(db: OpaquePointer?, char: String) -> (s86: String?, s98: String?, s06: String?) {
        let sql = """
            select s86, s98, s06 from wb_py_dict
            where text = ? and type = 'wb'
            and (s86 is not null or s98 is not null or s06 is not null)
            order by length(wbcode) desc, id asc limit 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return (nil, nil, nil)
        }
        sqlite3_bind_text(stmt, 1, char, -1, SQLITE_TRANSIENT)
        var s86: String?
        var s98: String?
        var s06: String?
        if sqlite3_step(stmt) == SQLITE_ROW {
            s86 = columnText(stmt, 0)
            s98 = columnText(stmt, 1)
            s06 = columnText(stmt, 2)
        }
        sqlite3_finalize(stmt)
        return (s86, s98, s06)
    }

    private static func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
        let val = String(cString: cStr)
        return val.isEmpty ? nil : val
    }

    private static func combineCompoundGlyph(_ glyphs: [String]) -> String {
        switch glyphs.count {
        case 2:
            return prefixCodePoints(glyphs[0], 2) + prefixCodePoints(glyphs[1], 2)
        case 3:
            return prefixCodePoints(glyphs[0], 1) + prefixCodePoints(glyphs[1], 1) + prefixCodePoints(glyphs[2], 2)
        default:
            return prefixCodePoints(glyphs[0], 1) + prefixCodePoints(glyphs[1], 1)
                + prefixCodePoints(glyphs[2], 1) + prefixCodePoints(glyphs[glyphs.count - 1], 1)
        }
    }

    /// 为多字词生成组合拆字（2字各取前2码点、3字前二字首码点+末字前2码点、≥4字前三字首码点+末字首码点）
    static func fillCompoundGlyphs(db: OpaquePointer?, text: String, skipIfExists: Bool = false) {
        let chars = codePoints(text)
        guard chars.count > 1 else { return }

        var needFill = [true, true, true]
        if skipIfExists {
            let checkSql = "select s86, s98, s06 from wb_py_dict where text = ? and type = 'user' limit 1"
            var checkStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(checkStmt, 1, text, -1, SQLITE_TRANSIENT)
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    for i in 0..<3 where sqlite3_column_type(checkStmt, Int32(i)) != SQLITE_NULL {
                        needFill[i] = false
                    }
                }
            }
            sqlite3_finalize(checkStmt)
            if !needFill.contains(true) { return }
        }

        var perCharGlyphs: [[String]] = Array(repeating: [], count: 3)
        for char in chars {
            let (g86, g98, g06) = getCharGlyphs(db: db, char: char)
            if needFill[0] {
                guard let g = g86 else { return }
                perCharGlyphs[0].append(g)
            }
            if needFill[1] {
                guard let g = g98 else { return }
                perCharGlyphs[1].append(g)
            }
            if needFill[2] {
                guard let g = g06 else { return }
                perCharGlyphs[2].append(g)
            }
        }

        let results: [String?] = zip(needFill, perCharGlyphs).map { need, glyphs in
            guard need, glyphs.count == chars.count else { return nil }
            let combined = combineCompoundGlyph(glyphs)
            return combined.isEmpty ? nil : combined
        }
        guard results.contains(where: { $0 != nil }) else { return }

        let upSql = """
            update wb_py_dict set
                s86 = coalesce(?1, s86),
                s98 = coalesce(?2, s98),
                s06 = coalesce(?3, s06)
            where text = ?4 and type = 'user'
        """
        var up: OpaquePointer?
        guard sqlite3_prepare_v2(db, upSql, -1, &up, nil) == SQLITE_OK else { return }
        for (i, value) in results.enumerated() {
            let idx = Int32(i + 1)
            if let value = value {
                sqlite3_bind_text(up, idx, value, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(up, idx)
            }
        }
        sqlite3_bind_text(up, 4, text, -1, SQLITE_TRANSIENT)
        sqlite3_step(up)
        sqlite3_finalize(up)
    }
}
