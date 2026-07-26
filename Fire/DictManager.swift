//
//  DictManager.swift
//  Fire
//
//  Created by 虚幻 on 2022/7/2.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import Defaults

class DictManager {
    static let shared = DictManager()
    static let userDictUpdated = Notification.Name("DictManager.userDictUpdated")

    let tempEnTriggerPunctuation: Character = ";"

    /// 解析用户词库行，支持双引号包裹含空格的词组
    /// 例: "abc \"hello world\" test" → ["abc", "hello world", "test"]
    private func parseQuoteAware(line: Substring) -> [Substring] {
        var result: [Substring] = []
        var current = line[...]
        while !current.isEmpty {
            current = current.drop(while: { $0.isWhitespace })
            guard !current.isEmpty else { break }
            if current.first == "\"" {
                current = current.dropFirst()
                let end = current.firstIndex(of: "\"") ?? current.endIndex
                result.append(current[..<end])
                current = current[end...]
                if current.first == "\"" { current = current.dropFirst() }
            } else {
                let end = current.firstIndex(where: { $0.isWhitespace }) ?? current.endIndex
                result.append(current[..<end])
                current = current[end...]
            }
        }
        return result
    }

    lazy var userDictFilePath: String = {
        let dirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        guard let dir = dirs.first, let bundleID = Bundle.main.bundleIdentifier else {
            return NSHomeDirectory() + "/Library/Application Support/Fire/user-dict.txt"
        }
        return dir + "/" + bundleID + "/user-dict.txt"
    }()

    /// 数据库指针（供 build.swift 迁移数据时读取）
    private(set) var database: OpaquePointer?
    private var queryStatement: OpaquePointer?

    private init() {
        // 监听编码模式、候选词数、生僻字开关等偏好变更，自动更新 SQL 查询语句
        Defaults.observe(keys: .codeMode, .candidateCount, .enableGBK, .enableEmoji) { () in
            self.prepareStatement()
        }
        .tieToLifetime(of: self)
    }
    deinit {
        close()
    }
    func reinit() {
        close()
        prepareStatement()
    }
    func close() {
        queryStatement = nil
        sqlite3_close_v2(database)
        sqlite3_shutdown()
        database = nil
    }

    private func getStatementSql() -> String {
        let candidateCount = Defaults[.candidateCount]
        let codeMode = Defaults[.codeMode]
        // 比显示的候选词数量多查一个，以此判断有没有下一页
        // GBK 过滤：关闭生僻字时只查 is_gb2312=1 的常用字
        let gbkFilter = !Defaults[.enableGBK] ? "and is_gb2312 = 1" : ""
        let typeFilter: String = {
            var types: [String]
            switch codeMode {
            case .wubi:
                types = ["wb", "user"]
            case .pinyin:
                types = ["py", "user"]
            case .wubiPinyin:
                types = ["wb", "py", "user"]
            }
            if Defaults[.enableEmoji] {
                types.append("emoji")
            }
            let quoted = types.map { "'\($0)'" }.joined(separator: ", ")
            return "and type in (\(quoted))"
        }()
        let sql = """
            WITH top_texts AS (
                SELECT 
                    text,
                    MIN(query) AS query,
                    MIN(id) AS min_id,
                    MAX(wbcode) as wbcode
                FROM wb_py_dict
                WHERE query glob :queryLike \(typeFilter) \(gbkFilter)
                  AND text NOT IN (SELECT text FROM blocked_words)  -- 排除屏蔽词
                GROUP BY text
                ORDER BY query, min_id                    -- 与原始排序一致
                LIMIT :offset, \(candidateCount + 1)                                   -- 提前截断，只取前5个 text
            )
            SELECT 
                MAX(t.wbcode) AS wbcode,
                d.text,
                MAX(d.type)     AS type,                  -- 假设 type 在组内相同，否则需明确逻辑
                t.query,
                MAX(d.spell)    AS spell,
                MAX(d.pinyin)   AS pinyin,
                MAX(d.is_gb2312)AS is_gb2312
            FROM wb_py_dict d
            JOIN top_texts t ON d.id = t.min_id
            GROUP BY d.text
            ORDER BY t.query, t.min_id;                   -- 保持原始排序
        """
        return sql
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

    private func prepareStatement() {
        if database == nil {
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
        if queryStatement != nil {
            sqlite3_finalize(queryStatement)
            queryStatement = nil
        }
        let sql = getStatementSql()
        // 日志输出实际执行的 SQL，方便调试查询问题
#if DEBUG
        FireLog.dict.debug("SQL: \(sql.replacingOccurrences(of: "\n", with: " "))")
#endif
        if sqlite3_prepare_v2(database, sql, -1, &queryStatement, nil) == SQLITE_OK {
            FireLog.dict.debug("prepare ok")
        } else if let err = sqlite3_errmsg(database) {
            FireLog.dict.error("prepare fail: \(String(cString: err), privacy: .public)")
        }
    }

    private func getMinIdFromDictTable() -> Int {
        let sql = "select min(id) from wb_py_dict"
        var minId: Int32 = 0
        sqliteQuery(database, sql) { stmt in
            minId = sqlite3_column_int(stmt, 0)
        }
        return Int(minId)
    }

    // replaceTextWithVars 中使用的 DateFormatter 提为 static let，避免重复创建
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy MM dd HH mm ss"
        return f
    }()

    private func replaceTextWithVars(_ text: String) -> String {
        let date = Date()
        let arr = DictManager.dateFormatter.string(from: date).split(separator: " ")
        let vars: [String: String] = [
            "{yyyy}": String(arr[0]),
            "{MM}": String(arr[1]),
            "{dd}": String(arr[2]),
            "{HH}": String(arr[3]),
            "{mm}": String(arr[4]),
            "{ss}": String(arr[5])
        ]
        var newText = text
        vars.forEach { (key, val) in
            newText = newText.replacingOccurrences(of: key, with: val)
        }
        FireLog.dict.debug("replaceTextWithVars: \(text), \(newText)")
        return newText
    }

    private func getQueryLike(_ origin: String) -> String {
        if origin.isEmpty {
            return origin
        }

        // 精确匹配开启时编码精确匹配（不加 *），关闭时逐码模糊匹配（加 *）
        // 精确匹配适用于用户已输入完整编码的情况，减少无关候选项；模糊匹配适用于边输入边看候选
        let suffix = Defaults[.enableExactMatch] ? "" : "*"

        if !Defaults[.zKeyQuery] {
            return origin + suffix
        }

        // z键查询，z不能放在首位
        guard let first = origin.first else { return origin }
        return String(first) + (String(origin.suffix(origin.count - 1))
            .replacingOccurrences(of: "z", with: "?")) + suffix
    }

    func punctuationCandidates(query: String) -> [Candidate] {
        let text = query.count == 1 ? query : String(query.suffix(query.count - 1))
        return [Candidate(
            code: query,
            text: text,
            type: .placeholder,
            label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")]
    }

    func getCandidates(query: String = String(), page: Int = 1) -> (candidates: [Candidate], hasNext: Bool) {
        if query.count <= 0 {
            return ([], false)
        }
        if query.first == tempEnTriggerPunctuation {
            return (candidates: punctuationCandidates(query: query), hasNext: false)
        }

        // prepareStatement 失败（如码表数据库列不匹配需要重建）时返回空候选
        // 防止用户使用时出现无响应或崩溃
        guard queryStatement != nil else {
            FireLog.dict.error("queryStatement is nil, db may need rebuild")
            return ([], false)
        }
        FireLog.dict.debug("getCandidates origin: \(query)")
        let startTime = CFAbsoluteTimeGetCurrent()
        let queryLike = getQueryLike(query)
        var candidates: [Candidate] = []
        sqlite3_reset(queryStatement)
        sqlite3_clear_bindings(queryStatement)
        sqlite3_bind_text(queryStatement,
                          sqlite3_bind_parameter_index(queryStatement, ":queryLike"),
                          queryLike, -1,
                          SQLITE_TRANSIENT
        )
        // 注：原实现还绑定了 :code 参数，但 SQL 查询中已不再使用该参数，故移除
        sqlite3_bind_int(queryStatement,
                         sqlite3_bind_parameter_index(queryStatement, ":offset"),
                         Int32((page - 1) * Defaults[.candidateCount])
        )
        #if DEBUG
        FireLog.dict.debug("query sql: \(String(cString: sqlite3_expanded_sql(self.queryStatement)))")
        #endif
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            guard let code = optString(queryStatement, 0),
                  var text = optString(queryStatement, 1) else { continue }
            let type = CandidateType(rawValue: optString(queryStatement, 2) ?? "") ?? .unknown
            if type == .user {
                text = replaceTextWithVars(text)
            }
            // 拆字（列4）、拼音（列5），用于候选反查提示
            var spelling: String?
            if let cstr = sqlite3_column_text(queryStatement, 4) {
                let val = String(cString: cstr)
                if !val.isEmpty { spelling = "〈\(val)〉" }
            }
            var pinyin: String?
            if let cstr = sqlite3_column_text(queryStatement, 5) {
                let val = String(cString: cstr)
                if !val.isEmpty { pinyin = val }
            }
            let candidate = Candidate(code: code, text: text, type: type, spelling: spelling, pinyin: pinyin)
            candidates.append(candidate)
        }
        let count = Defaults[.candidateCount]
        let allCount = candidates.count
        candidates = Array(candidates.prefix(count))


        let duration = CFAbsoluteTimeGetCurrent() - startTime
        FireLog.dict.debug("getCandidates query: \(query), duration: \(duration * 1000, privacy: .public)ms")
        return (candidates, hasNext: allCount > count)
    }

    func setCandidateToFirst(query: String, candidate: Candidate) {
        let newCandidate = Candidate(code: query, text: candidate.text, type: CandidateType.user)
        _ = prependCandidate(candidate: newCandidate)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    func prependCandidate(candidate: Candidate) -> Bool {
        // 插入用户词时自动从原始词库复制拆字/拼音，确保用户词也支持反查提示
        let sql = """
            insert into wb_py_dict(id, wbcode, text, type, query, spell, pinyin)
            values (
                (select MIN(id) - 1 from wb_py_dict), :code, :text, :type, :code,
                (select spell from wb_py_dict where text = :text and spell is not null limit 1),
                (select pinyin from wb_py_dict where text = :text and pinyin is not null limit 1)
            );
        """
        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement,
                sqlite3_bind_parameter_index(insertStatement, ":code"),
                              candidate.code, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement,
                              sqlite3_bind_parameter_index(insertStatement, ":text"),
                              candidate.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement,
                              sqlite3_bind_parameter_index(insertStatement, ":type"),
                              CandidateType.user.rawValue, -1, SQLITE_TRANSIENT)
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
                insertStatement = nil
                // 如果没有从码表复制到拆字数据（码表中无此词），按组词规则生成
                fillCompoundGlyphs(for: candidate.text)
                return true
            }
        }
        sqlite3_finalize(insertStatement)
        insertStatement = nil
        let errMsg = database != nil ? String(cString: sqlite3_errmsg(database)) : "nil"
        FireLog.dict.error("prependCandidate errmsg: \(errMsg, privacy: .public)")
        return false
    }

    func deleteCandidate(_ candidate: Candidate) {
        FireLog.dict.debug("deleteCandidate \(candidate.text) code=\(candidate.code) type=\(candidate.type.rawValue, privacy: .public)")
        // 删除策略改为"屏蔽"而非直接删除，防止重建索引后被删除的词典词重新出现
        // 用户词：删除 type='user' 记录清除排序调整，再插入 blocked 屏蔽原词典词
        // 词典词：直接插入 blocked 屏蔽
        if candidate.type == .user {
            let sql = "delete from wb_py_dict where text = :text and type = :type"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, sqlite3_bind_parameter_index(stmt, ":text"),
                                  candidate.text, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, sqlite3_bind_parameter_index(stmt, ":type"),
                                  CandidateType.user.rawValue, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) != SQLITE_DONE {
                    FireLog.dict.error("delete user failed: \(String(cString: sqlite3_errmsg(self.database)), privacy: .public)")
                }
            }
            sqlite3_finalize(stmt)
        }
        let blockSql = "insert or ignore into blocked_words(text) values (?)"
        var blockStmt: OpaquePointer?
        if sqlite3_prepare_v2(database, blockSql, -1, &blockStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(blockStmt, 1, candidate.text, -1, SQLITE_TRANSIENT)
            if sqlite3_step(blockStmt) != SQLITE_DONE {
                FireLog.dict.error("insert blocked_words failed: \(String(cString: sqlite3_errmsg(self.database)), privacy: .public)")
            }
        }
        sqlite3_finalize(blockStmt)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    /// 为多字词生成组合拆字并写入数据库（按五笔词组取码规则：2字各取前2码、3字前二字首码+末字前2码、≥4字前三字首码+末字首码）
    /// - Parameters:
    ///   - text: 候选词文本
    ///   - skipIfExists: 若该列已有拆字数据则跳过（批量导入时使用）
    private func fillCompoundGlyphs(for text: String, skipIfExists: Bool = false) {
        DictGlyphFill.fillCompoundGlyphs(db: database, text: text, skipIfExists: skipIfExists)
    }

    // 查询单个汉字的五笔全码(按长度降序取全码，避免拿到一码简码导致首根不全)
    func getCharFullWubiCode(_ char: String) -> String? {
        let sql = """
            select wbcode from wb_py_dict
            where text = :text and type = 'wb'
            order by length(wbcode) desc, id asc limit 1
        """
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt,
                              sqlite3_bind_parameter_index(stmt, ":text"),
                              char, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = String(cString: sqlite3_column_text(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        stmt = nil
        return result
    }

    // 按五笔词组取码规则为多字词生成编码：
    // 2 字: 字1前2 + 字2前2; 3 字: 字1首 + 字2首 + 字3前2; >=4 字: 字1首 + 字2首 + 字3首 + 末字首
    // 任一字查不到五笔码则返回 nil
    func makeWubiWordCode(for text: String) -> String? {
        let chars = text.map { String($0) }
        guard chars.count >= 2 else { return nil }
        let codes = chars.map { getCharFullWubiCode($0) }
        guard codes.allSatisfy({ $0 != nil }) else { return nil }
        let fullCodes = codes.compactMap { $0 }
        func prefix(_ code: String, _ n: Int) -> String {
            return String(code.prefix(n))
        }
        switch fullCodes.count {
        case 2:
            return prefix(fullCodes[0], 2) + prefix(fullCodes[1], 2)
        case 3:
            return prefix(fullCodes[0], 1) + prefix(fullCodes[1], 1) + prefix(fullCodes[2], 2)
        default:
            return prefix(fullCodes[0], 1) + prefix(fullCodes[1], 1)
                + prefix(fullCodes[2], 1) + prefix(fullCodes[fullCodes.count - 1], 1)
        }
    }

    /// 批量插入用户词，使用参数化查询防止 SQL 注入
    func prependCandidates(candidates: [Candidate]) {
        if candidates.count <= 0 {
            return
        }
        // 2.1 先获取最小id
        let minId = getMinIdFromDictTable()
        // 2.2 逐条插入（参数化查询，避免字符串拼接）
        for (n, candidate) in candidates.enumerated() {
            let id = minId - candidates.count + n
            let sql = """
                insert into wb_py_dict(id, wbcode, text, type, query, spell, pinyin)
                values(?, ?, ?, ?, ?,
                    (select spell from wb_py_dict where text = ? and spell is not null limit 1),
                    (select pinyin from wb_py_dict where text = ? and pinyin is not null limit 1))
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_bind_text(stmt, 2, candidate.code, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, candidate.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, candidate.type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, candidate.code, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, candidate.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 7, candidate.text, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        // 为没有拆字数据的多字词生成组合拆字
        if candidates.count > 1 {
            for candidate in candidates where candidate.text.count > 1 {
                fillCompoundGlyphs(for: candidate.text, skipIfExists: true)
            }
        }
    }

    func updateUserDict(_ dictContent: String) {
        // 使用事务确保删除+插入原子性，防止数据丢失
        sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)
        // 1. 先删除之前的用户词库（type 为枚举常量，安全）
        sqlite3_exec(database, "delete from wb_py_dict where type = '\(CandidateType.user.rawValue)'", nil, nil, nil)
        // 2. 添加用户词库
        let lines = dictContent.split(whereSeparator: \.isNewline)
        FireLog.dict.debug("updateUserDict: \(lines.count, privacy: .public) lines")
        let candidates = lines.map { (line) -> [Candidate] in
            let parts = parseQuoteAware(line: line)
            guard parts.count >= 2 else { return [] }
            let code = String(parts[0])
            let candidateTexts = parts[1...]
            return candidateTexts.map { Candidate(code: code, text: String($0), type: CandidateType.user) }
        }.reduce([] as [Candidate]) { partialResult, cur in
            partialResult + cur
        }
        prependCandidates(candidates: candidates)
        sqlite3_exec(database, "COMMIT", nil, nil, nil)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    func getUserCandidates() -> [Candidate] {
        let sql = "select query, text from wb_py_dict where type = '\(CandidateType.user.rawValue)'"
        var candidates: [Candidate] = []
        sqliteQuery(database, sql) { stmt in
            guard let code = optString(stmt, 0), let text = optString(stmt, 1) else { return }
            candidates.append(Candidate(code: code, text: text, type: .user))
        }
        return candidates
    }

    /// 查询原始码表条目数（供 UI 验证重建结果）
    func queryBaseDictCount() -> Int {
        let sql = "select count(*) from wb_py_dict where type = 'wb' and version is null"
        var count = 0
        sqliteQuery(database, sql) { stmt in
            count = Int(sqlite3_column_int(stmt, 0))
        }
        return count
    }

    /// 导出完整码表（含用户词），编码 词1 词2 ... 格式
    ///
    /// 过滤规则：
    /// - type='wb' 或 type='user': 五笔词 + 用户词
    /// - version IS NULL: 排除拆字合并插入的汉字
    /// - text NOT IN blocked: 排除已屏蔽词
    func exportFullDictContent() -> String {
        let sql = """
            select query, group_concat(text, ' ') as texts from wb_py_dict
            where type in ('wb', 'user') and version is null
            and not exists (select 1 from blocked_words b where b.text = wb_py_dict.text)
            group by query order by query
        """
        var lines: [String] = []
        sqliteQuery(database, sql) { stmt in
            guard let code = optString(stmt, 0), let texts = optString(stmt, 1) else { return }
            lines.append("\(code) \(texts)")
        }
        return lines.joined(separator: "\n")
    }

    // 查询所有被屏蔽的词，用于用户词库面板中展示"已屏蔽词"列表
    func getBlockedWords() -> [String] {
        let sql = "select text from blocked_words order by text"
        var words: [String] = []
        sqliteQuery(database, sql) { stmt in
            guard let cstr = sqlite3_column_text(stmt, 0) else { return }
            words.append(String(cString: cstr))
        }
        return words
    }

    // 取消屏蔽：删除 type='blocked' 记录
    func unblockWord(_ text: String) {
        let sql = "delete from blocked_words where text = ?"
        sqliteQuery(database, sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, text, -1, SQLITE_TRANSIENT)
        }) { _ in }
    }

    // 检查某个词是否已被屏蔽（用于组词时判断）
    func isBlocked(_ text: String) -> Bool {
        let sql = "select count(*) from blocked_words where text = ?"
        var result = false
        sqliteQuery(database, sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, text, -1, SQLITE_TRANSIENT)
        }) { stmt in
            result = sqlite3_column_int(stmt, 0) > 0
        }
        return result
    }

    func getUserDictContent() -> String {
        // 获取用户候选词(包括调整顺序的词)
        struct UserDictLine {
            let code: String
            var texts: [String]
        }
        let candidates = getUserCandidates()
        FireLog.dict.debug("exportUserDictToFile candidates: \(candidates.count, privacy: .public)")
        var list: [UserDictLine] = []
        candidates.forEach { candidate in
            let index = list.firstIndex { dictItem in
                dictItem.code == candidate.code
            }
            if index == nil {
                list.append(UserDictLine(code: candidate.code, texts: [candidate.text]))
            } else if !list[index!].texts.contains(candidate.text) {
                list[index!].texts.append(candidate.text)
            }
        }
        let content = list.map { dictItem in
            ([dictItem.code] + dictItem.texts.map { text in
                text.contains(" ") ? "\"\(text)\"" : text
            }).joined(separator: " ")
        }
        .joined(separator: "\n")
        return content
    }

    /// 获取用户词表的结构化行数据（供表格编辑器使用）
    func getUserDictRows() -> [(code: String, candidates: [String])] {
        let candidates = getUserCandidates()
        var dict: [String: [String]] = [:]
        for candidate in candidates {
            if dict[candidate.code] == nil {
                dict[candidate.code] = [candidate.text]
            } else if !(dict[candidate.code]?.contains(candidate.text) ?? false) {
                dict[candidate.code]?.append(candidate.text)
            }
        }
        return dict.map { (code: $0.key, candidates: $0.value) }
            .sorted { $0.code < $1.code }
    }
}
