//
//  DictWriter.swift
//  Fire
//
//  Extracted from DictManager.swift: write-path dictionary mutation logic.
//

import Foundation

final class DictWriter {
    private var database: OpaquePointer?

    func bind(database: OpaquePointer?) {
        self.database = database
    }

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

    private func getMinIdFromDictTable() -> Int {
        let sql = "select min(id) from wb_py_dict"
        var minId: Int32 = 0
        sqliteQuery(database, sql) { stmt in
            minId = sqlite3_column_int(stmt, 0)
        }
        return Int(minId)
    }

    /// 为多字词生成组合拆字并写入数据库（按五笔词组取码规则：2字各取前2码、3字前二字首码+末字前2码、≥4字前三字首码+末字首码）
    /// - Parameters:
    ///   - text: 候选词文本
    ///   - skipIfExists: 若该列已有拆字数据则跳过（批量导入时使用）
    private func fillCompoundGlyphs(for text: String, skipIfExists: Bool = false) {
        DictGlyphFill.fillCompoundGlyphs(db: database, text: text, skipIfExists: skipIfExists)
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

    /// 仅写库；不发通知（通知由 Manager 发）
    func setCandidateToFirst(query: String, candidate: Candidate) -> Bool {
        let newCandidate = Candidate(code: query, text: candidate.text, type: CandidateType.user)
        return prependCandidate(candidate: newCandidate)
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

    // 删除策略改为"屏蔽"而非直接删除，防止重建索引后被删除的词典词重新出现
    // 用户词：删除 type='user' 记录清除排序调整，再插入 blocked 屏蔽原词典词
    // 词典词：直接插入 blocked 屏蔽
    // 不发通知（通知由 Manager 发）
    func deleteCandidate(_ candidate: Candidate) {
        FireLog.dict.debug("deleteCandidate \(candidate.text) code=\(candidate.code) type=\(candidate.type.rawValue, privacy: .public)")
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
    }

    // 不发通知（通知由 Manager 发）
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
    }

    // 取消屏蔽：删除 type='blocked' 记录（不发通知）
    func unblockWord(_ text: String) {
        let sql = "delete from blocked_words where text = ?"
        sqliteQuery(database, sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, text, -1, SQLITE_TRANSIENT)
        }) { _ in }
    }
}
