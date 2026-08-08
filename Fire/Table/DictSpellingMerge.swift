//
//  DictSpellingMerge.swift
//  Fire
//
//  将一份五笔拆字 + 固定拼音 spell 合并到 wb_py_dict，并预计算多字词组合。
//

import Foundation

enum DictSpellingMerge {
    /// 五笔 spell：`字\t拆字`
    static func loadWbSpellFile(_ path: String) -> [String: String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("[DictSpellingMerge] wb spell file not found: \(path)")
            return [:]
        }
        var result: [String: String] = [:]
        for line in content.split(whereSeparator: \.isNewline) {
            let parts = splitBy(String(line), delim: "\t", maxSplits: 1)
            guard parts.count >= 2 else { continue }
            let ch = parts[0]
            let glyphs = parts[1].replacingOccurrences(of: "※", with: "")
            if !ch.isEmpty, !glyphs.isEmpty {
                result[ch] = glyphs
            }
        }
        print("[DictSpellingMerge] loaded \(result.count) wb spell entries from \(path)")
        return result
    }

    /// 拼音 spell：`字\t拼音`
    static func loadPinyinSpellFile(_ path: String) -> [String: String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("[DictSpellingMerge] pinyin spell file not found: \(path)")
            return [:]
        }
        var result: [String: String] = [:]
        for line in content.split(whereSeparator: \.isNewline) {
            let parts = splitBy(String(line), delim: "\t", maxSplits: 1)
            guard parts.count >= 2 else { continue }
            let ch = parts[0]
            let pinyin = parts[1]
            if !ch.isEmpty, !pinyin.isEmpty {
                result[ch] = pinyin
            }
        }
        print("[DictSpellingMerge] loaded \(result.count) pinyin entries from \(path)")
        return result
    }

    /// 仅更新码表已有词条；不插入 spell 多出的字。
    static func merge(db: OpaquePointer?, wbSpellPath: String, pinyinSpellPath: String) -> Bool {
        let glyphs = loadWbSpellFile(wbSpellPath)
        let pinyins = loadPinyinSpellFile(pinyinSpellPath)

        var allChars = Set(glyphs.keys)
        allChars.formUnion(pinyins.keys)
        print("[DictSpellingMerge] unique chars in spell sources: \(allChars.count)")

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        let createSp = """
            create temp table sp(ch text primary key, spell text, pinyin text)
            """
        guard sqlite3_exec(db, createSp, nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] create temp sp failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }

        var ins: OpaquePointer?
        guard sqlite3_prepare_v2(db, "insert into sp values(?1,?2,?3)", -1, &ins, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] prepare sp insert failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        for ch in allChars {
            let g = glyphs[ch] ?? ""
            let p = pinyins[ch] ?? ""
            if g.isEmpty && p.isEmpty { continue }
            sqlite3_reset(ins)
            sqlite3_clear_bindings(ins)
            sqlite3_bind_text(ins, 1, ch, -1, SQLITE_TRANSIENT)
            if g.isEmpty {
                sqlite3_bind_null(ins, 2)
            } else {
                sqlite3_bind_text(ins, 2, g, -1, SQLITE_TRANSIENT)
            }
            if p.isEmpty {
                sqlite3_bind_null(ins, 3)
            } else {
                sqlite3_bind_text(ins, 3, p, -1, SQLITE_TRANSIENT)
            }
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
            spell = coalesce((select spell from sp where sp.ch = wb_py_dict.text), spell),
            pinyin = coalesce((select pinyin from sp where sp.ch = wb_py_dict.text), pinyin)
            where text in (select ch from sp)
            """
        guard sqlite3_exec(db, updateSQL, nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] update failed: \(errmsg(db))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        print("[DictSpellingMerge] updated: \(sqlite3_changes(db))")

        guard sqlite3_exec(db, "END TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            print("[DictSpellingMerge] commit failed: \(errmsg(db))")
            return false
        }
        print("[DictSpellingMerge] merge spelling done")

        return fillPhraseSpellings(db: db, glyphMap: glyphs, pinyinMap: pinyins)
    }

    /// 预计算多字词拆字与拼音（规则与 DictGlyphFill.combineCompoundGlyph 一致）
    private static func fillPhraseSpellings(
        db: OpaquePointer?,
        glyphMap: [String: String],
        pinyinMap: [String: String]
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
        let upSQL = "update wb_py_dict set spell=coalesce(?1, spell), pinyin=coalesce(?2, pinyin) where text=?3"
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

            var glyphParts: [String] = []
            var pinyinParts: [String] = []
            var glyphsOK = true
            var pinyinOK = true
            for char in chars {
                if let g = glyphMap[char], !g.isEmpty {
                    glyphParts.append(g)
                } else {
                    glyphsOK = false
                }
                if let p = pinyinMap[char], !p.isEmpty {
                    pinyinParts.append(p)
                } else {
                    pinyinOK = false
                }
            }

            var combinedSpell: String?
            var combinedPinyin: String?
            if glyphsOK, glyphParts.count == chars.count {
                let combined = DictGlyphFill.combineCompoundGlyph(glyphParts)
                if !combined.isEmpty { combinedSpell = combined }
            }
            if pinyinOK, pinyinParts.count == chars.count {
                combinedPinyin = pinyinParts.joined(separator: "，")
            }
            guard combinedSpell != nil || combinedPinyin != nil else { continue }

            sqlite3_reset(updateStmt)
            sqlite3_clear_bindings(updateStmt)
            if let combinedSpell {
                sqlite3_bind_text(updateStmt, 1, combinedSpell, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(updateStmt, 1)
            }
            if let combinedPinyin {
                sqlite3_bind_text(updateStmt, 2, combinedPinyin, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(updateStmt, 2)
            }
            sqlite3_bind_text(updateStmt, 3, text, -1, SQLITE_TRANSIENT)
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

    private static func errmsg(_ db: OpaquePointer?) -> String {
        guard let db = db, let c = sqlite3_errmsg(db) else { return "unknown" }
        return String(cString: c)
    }
}
