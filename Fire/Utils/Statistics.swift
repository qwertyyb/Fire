//
//  Statistics.swift
//  Fire
//
//  Created by 虚幻 on 2022/5/22.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import Defaults
import KeychainSwift
import NanoID

struct DateCount: Hashable {
    let count: Int64
    let date: String
}

class Statistics {
    static let shared = Statistics()

    static let updated = Notification.Name("Statistics.updated")

    /// 串行队列：保护单一 SQLite 连接，允许后台查询而不阻塞主线程
    private let dbQueue = DispatchQueue(label: "com.qwertyyb.inputmethod.Fire.statistics.db")

    init() {
        NSLog("[Statistics] init")
        NotificationCenter.default
            .addObserver(self, selector: #selector(listener), name: Fire.candidateInserted, object: nil)
        initDB()
    }

    // 日期格式化器提为 static let，避免每次候选上屏时创建 DateFormatter 实例（性能优化）
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return f
    }()
    static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    @objc func listener(notification: Notification) {
        NSLog("[Statistics] listener: \(notification)")
        guard let candidate = notification.userInfo?["candidate"] as? Candidate else {
            return
        }
        if !Defaults[.enableStatistics] {
            return
        }
        if candidate.type == CandidateType.placeholder { return }

        let confirmed = notification.userInfo?["confirmed"] as? Bool ?? false
        dbQueue.async { [weak self] in
            self?.insertCandidate(candidate, confirmed: confirmed)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Statistics.updated, object: nil)
            }
        }
    }

    private func insertCandidate(_ candidate: Candidate, confirmed: Bool) {
        // 复用 prepared statement：首次调用时 prepare，后续只 reset + rebind，
        // 避免每次触发（候选上屏）都执行 prepare/finalize 的开销
        if insertStatement == nil {
            let sql = "insert into data(text, type, code, createdAt, confirmed) values (?1, ?2, ?3, ?4, ?5)"
            sqlite3_prepare_v2(database, sql, -1, &insertStatement, nil)
        }
        guard let stmt = insertStatement else { return }

        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        sqlite3_bind_text(stmt, 1, candidate.text, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, candidate.type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, candidate.code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, Statistics.dateFormatter.string(from: Date()), -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 5, confirmed ? 1 : 0)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("errmsg: \(dbErrMsg(database))")
        }
    }

    func queryCountByDate(startDate: Date, endDate: Date) -> [DateCount] {
        dbQueue.sync {
            queryCountByDateUnlocked(startDate: startDate, endDate: endDate)
        }
    }

    private func queryCountByDateUnlocked(startDate: Date, endDate: Date) -> [DateCount] {
        let start = Statistics.dateOnlyFormatter.string(from: startDate)
        let end = Statistics.dateOnlyFormatter.string(from: endDate)
        // 使用参数化查询避免 SQL 注入风险，同时保证 date 字符串格式正确
        let sql = """
            select date, count from
                (select
                    date(createdAt) as date,
                    sum(length(text)) as count
                from data
                where date(createdAt) >= ? and date(createdAt) <= ?
                group by date(createdAt))
            order by date desc;
        """
        var results: [DateCount] = []
        sqliteQuery(database, sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, start, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, end, -1, SQLITE_TRANSIENT)
        }) { stmt in
            guard let date = optString(stmt, 0) else { return }
            let count = sqlite3_column_int64(stmt, 1)
            results.append(DateCount(count: count, date: date))
        }
        return results.sorted { $1.date > $0.date }
    }

    func queryTotalCount() -> Int64 {
        dbQueue.sync {
            queryTotalCountUnlocked()
        }
    }

    private func queryTotalCountUnlocked() -> Int64 {
        let sql = "select sum(length(text)) as total from data"
        var total: Int64 = 0
        sqliteQuery(database, sql) { stmt in
            total = sqlite3_column_int64(stmt, 0)
        }
        return total
    }

    /// 平均码长 = (编码总按键数 + 确认键次数) / 上屏总字数
    func queryAvgCodeLen() -> Double {
        dbQueue.sync {
            queryAvgCodeLenUnlocked()
        }
    }

    private func queryAvgCodeLenUnlocked() -> Double {
        let sql = """
            select
                cast((sum(length(code)) + sum(confirmed)) as real) / sum(length(text)) as avgCodeLen
            from data
        """
        var avgCodeLen: Double = 0
        sqliteQuery(database, sql) { stmt in
            avgCodeLen = sqlite3_column_double(stmt, 0)
        }
        return avgCodeLen
    }

    /// 一次查出面板刷新所需全部数据（内部仍为原有三条查询，避免重复进出队列）
    func queryPaneSnapshot(startDate: Date, endDate: Date) -> (total: Int64, avgCodeLen: Double, data: [DateCount]) {
        dbQueue.sync {
            (
                queryTotalCountUnlocked(),
                queryAvgCodeLenUnlocked(),
                queryCountByDateUnlocked(startDate: startDate, endDate: endDate)
            )
        }
    }

    /// 清除所有统计数据
    func clear() {
        dbQueue.async { [weak self] in
            guard let self else { return }
            // 注意：SQLite 使用 DELETE FROM，不是 DELETE * FROM
            let sql = "delete from data"
            sqlite3_exec(self.database, sql, nil, nil, nil)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Statistics.updated, object: nil)
            }
        }
    }

    private var database: OpaquePointer?
    // insertStatement 作为成员变量缓存，避免每次候选上屏都 prepare/finalize
    private var insertStatement: OpaquePointer?
    private let keychain = KeychainSwift(keyPrefix: Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire")

    deinit {
        // 释放 SQLite 资源，防止进程退出时泄漏
        dbQueue.sync {
            sqlite3_finalize(insertStatement)
            sqlite3_close_v2(database)
        }
    }
    private let upgrade = [
        """
        CREATE TABLE IF NOT EXISTS "data" (
            "id" INTEGER PRIMARY KEY NOT NULL,
            "text" TEXT NOT NULL,
            "type" TEXT NOT NULL,
            "code" TEXT NOT NULL,
            "createdAt" TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """,
        """
        ALTER TABLE data ADD COLUMN confirmed INTEGER NOT NULL DEFAULT 1
        """
    ]

    private func getVersion() -> Int32 {
        let sql = "PRAGMA user_version"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK,
           sqlite3_step(stmt) == SQLITE_ROW {
            let version = sqlite3_column_int(stmt, 0)
            sqlite3_finalize(stmt)
            return version
        }
        sqlite3_finalize(stmt)
        return 0
    }

    private func setVersion(_ version: Int32) -> Bool {
        let sql = "PRAGMA user_version = \(version)"
        if sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK {
            return true
        }
        return false
    }

    private func migrate() -> Bool {
        let curVersion = getVersion()
        NSLog("[Statistics] migrate curVersion: \(curVersion)")
        if curVersion >= upgrade.count {
            return true
        }
        upgrade.forEach { sql in
            sqlite3_exec(database, sql, nil, nil, nil)
        }
        NSLog("[Statistics] migrate setVersion: \(upgrade.count)")
        return setVersion(Int32(upgrade.count))
    }

    private func initDB() {
        // 安全获取目录路径，避免 first! 崩溃
        let dirPath: String = {
            let dirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            guard let dir = dirs.first, let bundleID = Bundle.main.bundleIdentifier else {
                return NSHomeDirectory() + "/Library/Application Support/Fire"
            }
            return dir + "/" + bundleID
        }()

        // create parent directory iff it doesn’t exist
        try? FileManager.default.createDirectory(
            atPath: dirPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        NSLog("[Statistics] init DB, database path in \(dirPath)")
        guard let key = resolveDbKey() else { return }
        dbQueue.sync {
            if sqlite3_open_v2(
                dirPath + "/statistics.db",
                &database,
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                nil
            ) == SQLITE_OK {
                sqlite3_key(database, key, Int32(key.count))
                _ = migrate()
            } else {
                let errMsg = database != nil ? String(cString: sqlite3_errmsg(database)) : "nil"
                NSLog("[Statistics] init DB, open error: \(errMsg)")
            }
        }
    }

    /// 读取或创建统计库加密密钥。
    /// `KeychainSwift.get` 在「不存在」和「读取失败」时都返回 nil，
    /// 只有确认是 `errSecItemNotFound` 时才生成新钥匙，避免覆盖已有密钥。
    private func resolveDbKey() -> String? {
        if let key = keychain.get("dbkey") {
            return key
        }
        if keychain.lastResultCode != errSecItemNotFound {
            NSLog("[Statistics] read dbkey failed: \(keychain.lastResultCode)")
            return nil
        }
        let key = ID(alphabet: .urlSafe, size: 16).generate()
        // 首次解锁后即可读，避免登录窗口阶段读失败后误写新钥匙
        if !keychain.set(key, forKey: "dbkey", withAccess: .accessibleAfterFirstUnlock) {
            NSLog("[Statistics] write dbkey failed: \(keychain.lastResultCode)")
            return nil
        }
        return key
    }
}
