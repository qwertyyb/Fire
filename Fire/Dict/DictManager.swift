//
//  DictManager.swift
//  Fire
//
//  Created by 虚幻 on 2022/7/2.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import Defaults

class DictManager: EngineDictManager {
    static let shared = DictManager()
    static let userDictUpdated = Notification.Name("DictManager.userDictUpdated")

    lazy var userDictFilePath: String = {
        let dirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        guard let dir = dirs.first, let bundleID = Bundle.main.bundleIdentifier else {
            return NSHomeDirectory() + "/Library/Application Support/Fire/user-dict.txt"
        }
        return dir + "/" + bundleID + "/user-dict.txt"
    }()

    /// 数据库指针（供 build.swift 迁移数据时读取）
    private(set) var database: OpaquePointer?
    private let reader = DictReader()
    private let writer = DictWriter()

    private init() {
        // 监听编码模式、候选词数、生僻字开关等偏好变更，自动更新 SQL 查询语句
        Defaults.observe(keys: .codeMode, .candidateCount, .enableGBK, .enableEmoji) { () in
            self.ensureDatabaseOpen()
            self.reader.bind(database: self.database)
            self.writer.bind(database: self.database)
            self.reader.prepare()
        }
        .tieToLifetime(of: self)
    }
    deinit {
        close()
    }
    func reinit() {
        close()
        ensureDatabaseOpen()
        reader.bind(database: database)
        writer.bind(database: database)
        reader.prepare()
    }
    func close() {
        reader.teardown()
        sqlite3_close_v2(database)
        sqlite3_shutdown()
        database = nil
    }

    private func enableSQLiteProfile(_ db: OpaquePointer?) {
        guard let db = db else { return }
        
        // 注册 profile 回调
        sqlite3_profile(db, { _, sql, nanoseconds in
            /*
             * SQLite 内部计时精度 = 微秒级 / 毫秒级，不是纳秒级！
             * 虽然 sqlite3_profile 给你的单位是 纳秒（UInt64），
             * 但 SQLite 内部真正计时精度并没有那么高。
             * 它的时间来源是：
             * Windows：GetTickCount 精度 1ms ~ 16ms
             * macOS / iOS：mach_absolute_time 转成后对齐到毫秒级别
             */
            let ms = Double(nanoseconds) / 1_000_000
            let sqlStr = String(cString: sql!)
            
            FireLog.dict.debug("SQL duration: \(ms, privacy: .public)ms, sql: \(sqlStr)")
        }, nil)
    }

    private func ensureDatabaseOpen() {
        guard database == nil else { return }
        let rc = sqlite3_open_v2(getDatabaseURL().path, &database, SQLITE_OPEN_READWRITE, nil)
        guard rc == SQLITE_OK else {
            FireLog.dict.error("Failed to open database: \(String(cString: sqlite3_errmsg(self.database)), privacy: .public)")
            return
        }
#if DEBUG
        enableSQLiteProfile(database)
#endif
        sqlite3_exec(database, "PRAGMA case_sensitive_like=ON;", nil, nil, nil)
        // 限制 SQLite 页缓存为 2MB，防止候选词查询缓存持续增长占用过多内存
        sqlite3_exec(database, "PRAGMA cache_size=-2000;", nil, nil, nil)
    }

    func query(_ origin: String, page: Int = 1) -> (candidates: [Candidate], hasNext: Bool) {
        reader.getCandidates(query: origin, page: page)
    }

    func setCandidateToFirst(_ query: String, candidate: Candidate) {
        _ = writer.setCandidateToFirst(query: query, candidate: candidate)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    func addUserText(origin: String, text: String) {
        let _ = writer.prependCandidate(candidate: Candidate(code: origin, text: text, type: .user))
    }

    func blockCandidate(_ candidate: Candidate) {
        writer.deleteCandidate(candidate)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    /// 查询文本的五笔编码：单字返回全码，多字按词组规则合成
    func queryWubiCode(_ text: String) -> String? {
        reader.queryWubiCode(text)
    }

    /// 批量插入用户词，使用参数化查询防止 SQL 注入
    func prependCandidates(candidates: [Candidate]) {
        writer.prependCandidates(candidates: candidates)
    }

    func updateUserDict(_ dictContent: String) {
        writer.updateUserDict(dictContent)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    /// 查询原始码表条目数（供 UI 验证重建结果）
    func queryBaseDictCount() -> Int {
        reader.queryBaseDictCount()
    }

    /// 导出完整码表（含用户词），编码 词1 词2 ... 格式
    ///
    /// 过滤规则：
    /// - type='wb' 或 type='user': 五笔词 + 用户词
    /// - version IS NULL: 排除拆字合并插入的汉字
    /// - text NOT IN blocked: 排除已屏蔽词
    func exportFullDictContent() -> String {
        reader.exportFullDictContent()
    }

    // 查询所有被屏蔽的词，用于用户词库面板中展示"已屏蔽词"列表
    func getBlockedWords() -> [String] {
        reader.getBlockedWords()
    }

    // 取消屏蔽：删除 type='blocked' 记录
    func unblockText(_ text: String) {
        writer.unblockWord(text)
    }

    // 检查某个词是否已被屏蔽（用于组词时判断）
    func isBlocked(_ text: String) -> Bool {
        reader.isBlocked(text)
    }

    func exportUserDictContent() -> String {
        reader.exportUserDictContent()
    }

    /// 获取用户词表的结构化行数据（供表格编辑器使用）
    func getUserDictRows() -> [(code: String, candidates: [String])] {
        reader.getUserDictRows()
    }
}
