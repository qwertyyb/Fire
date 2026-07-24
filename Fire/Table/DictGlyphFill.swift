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

    /// 从码表单字行取拆字（优先五笔全码行）
    static func getCharGlyph(db: OpaquePointer?, char: String) -> String? {
        let sql = """
            select spell from wb_py_dict
            where text = ? and type = 'wb'
            and spell is not null
            order by length(wbcode) desc, id asc limit 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        sqlite3_bind_text(stmt, 1, char, -1, SQLITE_TRANSIENT)
        var spell: String?
        if sqlite3_step(stmt) == SQLITE_ROW {
            spell = columnText(stmt, 0)
        }
        sqlite3_finalize(stmt)
        return spell
    }

    private static func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
        let val = String(cString: cStr)
        return val.isEmpty ? nil : val
    }

    /// 多字词拆字组合：2字各取前2码点、3字前二字首码点+末字前2码点、≥4字前三字首码点+末字首码点
    static func combineCompoundGlyph(_ glyphs: [String]) -> String {
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

    /// 为多字词生成组合拆字并写入用户词
    static func fillCompoundGlyphs(db: OpaquePointer?, text: String, skipIfExists: Bool = false) {
        let chars = codePoints(text)
        guard chars.count > 1 else { return }

        if skipIfExists {
            let checkSql = "select spell from wb_py_dict where text = ? and type = 'user' limit 1"
            var checkStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(checkStmt, 1, text, -1, SQLITE_TRANSIENT)
                if sqlite3_step(checkStmt) == SQLITE_ROW,
                   sqlite3_column_type(checkStmt, 0) != SQLITE_NULL {
                    sqlite3_finalize(checkStmt)
                    return
                }
            }
            sqlite3_finalize(checkStmt)
        }

        var perCharGlyphs: [String] = []
        for char in chars {
            guard let g = getCharGlyph(db: db, char: char) else { return }
            perCharGlyphs.append(g)
        }
        guard perCharGlyphs.count == chars.count else { return }

        let combined = combineCompoundGlyph(perCharGlyphs)
        guard !combined.isEmpty else { return }

        let upSql = """
            update wb_py_dict set spell = coalesce(?1, spell)
            where text = ?2 and type = 'user'
        """
        var up: OpaquePointer?
        guard sqlite3_prepare_v2(db, upSql, -1, &up, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(up, 1, combined, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(up, 2, text, -1, SQLITE_TRANSIENT)
        sqlite3_step(up)
        sqlite3_finalize(up)
    }
}
