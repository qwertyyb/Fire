//
//  CharsetGB2312.swift
//  Fire
//
//  用系统 EUC_CN（IANA: gb2312）判断单字是否属于 GB2312。
//

import Foundation

enum CharsetGB2312 {
    /// macOS 上可用的 GB2312 编码（CFStringEncodings.GB_2312_80 通常不可用）
    private static let encoding: String.Encoding = {
        let raw = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.EUC_CN.rawValue)
        )
        return String.Encoding(rawValue: raw)
    }()

    /// 判断单个 Unicode 标量/单字是否可无损编码为 GB2312。
    /// - Note: ASCII 等 GB2312 收录的非汉字也会返回 true；多字串要求每个字符都在集内。
    static func contains(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return (text as NSString).canBeConverted(to: encoding.rawValue)
    }

    /// 批量更新库中所有单字行的 is_gb2312
    @discardableResult
    static func updateDatabaseFlags(db: OpaquePointer?) -> Bool {
        var selectStmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "select distinct text from wb_py_dict where length(text) = 1",
            -1,
            &selectStmt,
            nil
        ) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(selectStmt) }

        var chars: [String] = []
        while sqlite3_step(selectStmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(selectStmt, 0) {
                chars.append(String(cString: c))
            }
        }

        var updateStmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "update wb_py_dict set is_gb2312 = ?1 where text = ?2",
            -1,
            &updateStmt,
            nil
        ) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(updateStmt) }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        var gbCount = 0
        for ch in chars {
            let gb = contains(ch) ? 1 : 0
            if gb == 1 { gbCount += 1 }
            sqlite3_reset(updateStmt)
            sqlite3_clear_bindings(updateStmt)
            sqlite3_bind_int(updateStmt, 1, Int32(gb))
            sqlite3_bind_text(updateStmt, 2, ch, -1, SQLITE_TRANSIENT)
            if sqlite3_step(updateStmt) != SQLITE_DONE {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                return false
            }
        }
        guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
            return false
        }
        print("[CharsetGB2312] updated \(chars.count) chars, gb2312=\(gbCount)")
        return true
    }
}
