//
//  DictSpellingMerge.swift
//  Fire
//
//  合并三版五笔拆字/拼音到 wb_py_dict，并预计算多字词组合。
//

import Foundation

enum DictSpellingMerge {
    struct SpellingEntry {
        var ch: String = ""
        var glyphs: String = ""
        var wbcode: String = ""
        var pinyin: String = ""
        var isGB2312: Bool = false
    }

    private struct MergedRow {
        let ch: String
        let ver: String
        let wbcode: String
        let g86: String
        let g98: String
        let g06: String
        let py86: String
        let py98: String
        let py06: String
        let gb: Int
    }

    static func parseSpellingLine(_ line: String) -> SpellingEntry {
        var entry = SpellingEntry()
        let parts = splitBy(line, delim: "\t", maxSplits: 1)
        guard parts.count >= 2 else { return entry }
        entry.ch = parts[0]

        var data = parts[1]
        guard let lb = data.firstIndex(of: "["),
              let rb = data.firstIndex(of: "]"),
              lb < rb else { return entry }
        data = String(data[data.index(after: lb)..<rb])

        let fields = splitBy(data, delim: ",")
        guard !fields.isEmpty else { return entry }

        entry.glyphs = fields[0].replacingOccurrences(of: "※", with: "")
        if fields.count >= 2 {
            entry.wbcode = fields[1].replacingOccurrences(of: "※", with: "")
        }
        if fields.count >= 3 {
            entry.pinyin = fields[2].replacingOccurrences(of: "※", with: "")
        }
        if fields.count >= 4 {
            entry.isGB2312 = fields[3].contains("GB2312")
        }
        return entry
    }

    static func loadSpellingFile(_ path: String) -> [String: SpellingEntry] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("[DictSpellingMerge] spelling file not found: \(path)")
            return [:]
        }
        var result: [String: SpellingEntry] = [:]
        for line in content.split(whereSeparator: \.isNewline) {
            let entry = parseSpellingLine(String(line))
            if !entry.ch.isEmpty {
                result[entry.ch] = entry
            }
        }
        print("[DictSpellingMerge] loaded \(result.count) entries from \(path)")
        return result
    }

    static func merge(db: OpaquePointer?, s86Path: String, s98Path: String, s06Path: String) -> Bool {
        let s86 = loadSpellingFile(s86Path)
        let s98 = loadSpellingFile(s98Path)
        let s06 = loadSpellingFile(s06Path)

        var allChars = Set(s86.keys)
        allChars.formUnion(s98.keys)
        allChars.formUnion(s06.keys)

        var rows: [MergedRow] = []
        rows.reserveCapacity(allChars.count)
        var glyphMap: [String: (g86: String, g98: String, g06: String, py86: String, py98: String, py06: String)] = [:]

        for ch in allChars {
            let e86 = s86[ch]
            let e98 = s98[ch]
            let e06 = s06[ch]

            let g86 = e86?.glyphs ?? ""
            let g98 = e98?.glyphs ?? ""
            let g06 = e06?.glyphs ?? ""
            let py86 = e86?.pinyin ?? ""
            let py98 = e98?.pinyin ?? ""
            let py06 = e06?.pinyin ?? ""
            let wb86 = e86?.wbcode ?? ""
            let wb98 = e98?.wbcode ?? ""
            let wb06 = e06?.wbcode ?? ""

            let gb = (e86?.isGB2312 == true || e98?.isGB2312 == true || e06?.isGB2312 == true) ? 1 : 0
            let wb: String
            let ver: String
            if !wb86.isEmpty {
                wb = wb86; ver = "86"
            } else if !wb98.isEmpty {
                wb = wb98; ver = "98"
            } else {
                wb = wb06; ver = "06"
            }

            rows.append(MergedRow(
                ch: ch, ver: ver, wbcode: wb,
                g86: g86, g98: g98, g06: g06,
                py86: py86, py98: py98, py06: py06, gb: gb
            ))
            glyphMap[ch] = (g86, g98, g06, py86, py98, py06)
        }
        print("[DictSpellingMerge] total unique chars: \(rows.count)")

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        let createSp = """
            create temp table sp(ch text primary key, ver text, wbcode text,
            g86 text, g98 text, g06 text, py86 text, py98 text, py06 text, gb int)
            """
        guard sqlite3_exec(db, createSp, nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] create temp sp failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }

        var ins: OpaquePointer?
        guard sqlite3_prepare_v2(db, "insert into sp values(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)", -1, &ins, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] prepare sp insert failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        for r in rows {
            sqlite3_reset(ins)
            sqlite3_clear_bindings(ins)
            sqlite3_bind_text(ins, 1, r.ch, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 2, r.ver, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 3, r.wbcode, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 4, r.g86, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 5, r.g98, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 6, r.g06, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 7, r.py86, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 8, r.py98, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(ins, 9, r.py06, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(ins, 10, Int32(r.gb))
            if sqlite3_step(ins) != SQLITE_DONE {
                print("[DictSpellingMerge] sp insert failed: \(errmsg(db))")
                sqlite3_finalize(ins)
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                return false
            }
        }
        sqlite3_finalize(ins)
        print("[DictSpellingMerge] temp table populated")

        let updateSQL = """
            update wb_py_dict set
            s86 = coalesce((select g86 from sp where sp.ch = wb_py_dict.text), s86),
            s98 = coalesce((select g98 from sp where sp.ch = wb_py_dict.text), s98),
            s06 = coalesce((select g06 from sp where sp.ch = wb_py_dict.text), s06),
            py86 = coalesce((select py86 from sp where sp.ch = wb_py_dict.text), py86),
            py98 = coalesce((select py98 from sp where sp.ch = wb_py_dict.text), py98),
            py06 = coalesce((select py06 from sp where sp.ch = wb_py_dict.text), py06),
            is_gb2312 = (select gb from sp where sp.ch = wb_py_dict.text)
            where text in (select ch from sp)
            """
        guard sqlite3_exec(db, updateSQL, nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] update failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        print("[DictSpellingMerge] updated: \(sqlite3_changes(db))")

        let insertSQL = """
            insert into wb_py_dict(wbcode, text, type, query, version, s86, s98, s06, py86, py98, py06, is_gb2312)
            select sp.wbcode, sp.ch, 'wb', sp.wbcode, sp.ver,
            nullif(sp.g86,''), nullif(sp.g98,''), nullif(sp.g06,''),
            nullif(sp.py86,''), nullif(sp.py98,''), nullif(sp.py06,''), sp.gb
            from sp left join wb_py_dict on sp.ch = wb_py_dict.text
            where wb_py_dict.text is null
            """
        guard sqlite3_exec(db, insertSQL, nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] insert missing failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        print("[DictSpellingMerge] inserted: \(sqlite3_changes(db))")

        guard sqlite3_exec(db, "END TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] commit failed: \(errmsg(db))")
            return false
        }
        print("[DictSpellingMerge] merge spelling done")

        return fillPhraseSpellings(db: db, glyphMap: glyphMap)
    }

    /// 预计算多字词拆字与拼音（规则与 DictGlyphFill.combineCompoundGlyph 一致）
    private static func fillPhraseSpellings(
        db: OpaquePointer?,
        glyphMap: [String: (g86: String, g98: String, g06: String, py86: String, py98: String, py06: String)]
    ) -> Bool {
        print("[DictSpellingMerge] pre-computing phrase spellings...")
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        var phraseStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "select distinct text from wb_py_dict where length(text) > 1", -1, &phraseStmt, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] phrase select failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        defer { sqlite3_finalize(phraseStmt) }

        var updateStmt: OpaquePointer?
        let upSQL = "update wb_py_dict set s86=?1, s98=?2, s06=?3, py86=?4, py98=?5, py06=?6 where text=?7"
        guard sqlite3_prepare_v2(db, upSQL, -1, &updateStmt, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] phrase update prepare failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        defer { sqlite3_finalize(updateStmt) }

        var phraseCount = 0
        while sqlite3_step(phraseStmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(phraseStmt, 0) else { continue }
            let text = String(cString: cStr)
            let chars = DictGlyphFill.codePoints(text)
            guard chars.count >= 2 else { continue }

            var results = Array(repeating: "", count: 6)
            for ci in 0..<3 {
                var glyphs: [String] = []
                var pinyins: [String] = []
                var glyphsOK = true
                var pinyinOK = true
                for char in chars {
                    guard let entry = glyphMap[char] else {
                        glyphsOK = false
                        pinyinOK = false
                        break
                    }
                    let g: String
                    let p: String
                    switch ci {
                    case 0: g = entry.g86; p = entry.py86
                    case 1: g = entry.g98; p = entry.py98
                    default: g = entry.g06; p = entry.py06
                    }
                    if g.isEmpty { glyphsOK = false }
                    else { glyphs.append(g) }
                    if p.isEmpty { pinyinOK = false }
                    else { pinyins.append(p) }
                }
                if glyphsOK, glyphs.count == chars.count {
                    let combined = DictGlyphFill.combineCompoundGlyph(glyphs)
                    if !combined.isEmpty { results[ci] = combined }
                }
                if pinyinOK, pinyins.count == chars.count {
                    results[ci + 3] = pinyins.joined(separator: "，")
                }
            }

            if results.allSatisfy(\.isEmpty) { continue }

            sqlite3_reset(updateStmt)
            sqlite3_clear_bindings(updateStmt)
            for i in 0..<6 {
                if results[i].isEmpty {
                    sqlite3_bind_null(updateStmt, Int32(i + 1))
                } else {
                    sqlite3_bind_text(updateStmt, Int32(i + 1), results[i], -1, SQLITE_TRANSIENT)
                }
            }
            sqlite3_bind_text(updateStmt, 7, text, -1, SQLITE_TRANSIENT)
            if sqlite3_step(updateStmt) != SQLITE_DONE {
                print("[DictSpellingMerge] phrase update failed: \(errmsg(db))")
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                return false
            }
            phraseCount += 1
        }

        guard sqlite3_exec(db, "END TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] phrase commit failed: \(errmsg(db))")
            return false
        }
        print("[DictSpellingMerge] phrase spellings updated: \(phraseCount)")
        return true
    }

    private static func splitBy(_ s: String, delim: Character, maxSplits: Int = -1) -> [String] {
        var result: [String] = []
        var cur = ""
        var splits = 0
        for ch in s {
            if ch == delim && (maxSplits < 0 || splits < maxSplits) {
                result.append(cur)
                cur = ""
                splits += 1
            } else {
                cur.append(ch)
            }
        }
        result.append(cur)
        return result
    }

    private static func splitBy(_ s: String, delim: String) -> [String] {
        s.split(separator: Character(delim), omittingEmptySubsequences: false).map(String.init)
    }

    private static func errmsg(_ db: OpaquePointer?) -> String {
        guard let db = db, let c = sqlite3_errmsg(db) else { return "unknown" }
        return String(cString: c)
    }
}
