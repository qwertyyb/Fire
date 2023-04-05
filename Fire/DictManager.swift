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

    let userDictFilePath = NSSearchPathForDirectoriesInDomains(
        .applicationSupportDirectory,
        .userDomainMask, true).first! + "/" + Bundle.main.bundleIdentifier! + "/user-dict.txt"

    private var database: OpaquePointer?
    private var queryStatement: OpaquePointer?

    private init() {
        Defaults.observe(keys: .codeMode, .candidateCount) { () in
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
        let sql = """
            select
                \(codeMode == .wubiPinyin ? "max(wbcode)" : "min(wbcode)"),
                text,
                type, min(query) as query
            from wb_py_dict
            where query glob :queryLike \(
                codeMode == .wubi ? "and type = 'wb'"
                                : codeMode == .pinyin ? "and type = 'py'" : "")
            group by text
            order by query, id
            limit :offset, \(candidateCount + 1)
        """
        return sql
    }

    private func prepareStatement() {
        if database == nil {
            sqlite3_open_v2(getDatabaseURL().path, &database, SQLITE_OPEN_READWRITE, nil)
            sqlite3_exec(database, "PRAGMA case_sensitive_like=ON;", nil, nil, nil)
        }
        if queryStatement != nil {
            sqlite3_finalize(queryStatement)
            queryStatement = nil
        }
        if sqlite3_prepare_v2(database, getStatementSql(), -1, &queryStatement, nil) == SQLITE_OK {
            print("prepare ok")
        } else if let err = sqlite3_errmsg(database) {
            print("prepare fail: \(err)")
        }
    }

    private func getMinIdFromDictTable() -> Int {
        let sql = "select min(id) from wb_py_dict"
        var queryStmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &queryStmt, nil) == SQLITE_OK {
            if sqlite3_step(queryStmt) == SQLITE_ROW {
                let minId = sqlite3_column_int(queryStmt, 0)
                sqlite3_finalize(queryStmt)
                queryStmt = nil
                return Int(minId)
            }
        }
        NSLog("[Fire.getMinIdFromDictTable] errmsg: \(String(cString: sqlite3_errmsg(queryStmt)))")
        sqlite3_finalize(queryStmt)
        queryStmt = nil
        return 0
    }

    private func replaceTextWithVars(_ text: String) -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MM dd HH mm ss"
        let arr = formatter.string(from: date).split(separator: " ")
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
        print("[replaceTextWithVars] \(text), \(newText)")
        return newText
    }

    private func getQueryLike(_ origin: String) -> String {
        if origin.isEmpty {
            return origin
        }

        if !Defaults[.zKeyQuery] {
            return origin + "*"
        }

        // z键查询，z不能放在首位
        let first = origin.first!
        return String(first) + (String(origin.suffix(origin.count - 1))
            .replacingOccurrences(of: "z", with: "?")) + "*"
    }

    func getCandidates(query: String = String(), page: Int = 1) -> (candidates: [Candidate], hasNext: Bool) {
        if query.count <= 0 {
            return ([], false)
        }
        NSLog("[DictManager] getCandidates origin: \(query)")
        let startTime = CFAbsoluteTimeGetCurrent()
        let queryLike = getQueryLike(query)
        var candidates: [Candidate] = []
        sqlite3_reset(queryStatement)
        sqlite3_clear_bindings(queryStatement)
        sqlite3_bind_text(queryStatement,
                        sqlite3_bind_parameter_index(queryStatement, ":code"),
                        query, -1,
                        SQLITE_TRANSIENT
        )
        sqlite3_bind_text(queryStatement,
                          sqlite3_bind_parameter_index(queryStatement, ":queryLike"),
                          queryLike, -1,
                          SQLITE_TRANSIENT
        )
        sqlite3_bind_int(queryStatement,
                         sqlite3_bind_parameter_index(queryStatement, ":offset"),
                         Int32((page - 1) * Defaults[.candidateCount])
        )
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            let code = String.init(cString: sqlite3_column_text(queryStatement, 0))
            var text = String.init(cString: sqlite3_column_text(queryStatement, 1))
            let type = CandidateType(rawValue: String.init(cString: sqlite3_column_text(queryStatement, 2)))!
            if type == .user {
                text = replaceTextWithVars(text)
            }
            let candidate = Candidate(code: code, text: text, type: type)
            candidates.append(candidate)
        }
        let count = Defaults[.candidateCount]
        let allCount = candidates.count
        candidates = Array(candidates.prefix(count))

        if candidates.isEmpty {
            candidates.append(Candidate(code: query, text: query, type: CandidateType.placeholder))
        }
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        NSLog("[DictManager] getCandidates query: \(query) , duration: \(duration)")
        return (candidates, hasNext: allCount > count)
    }

    func setCandidateToFirst(query: String, candidate: Candidate) {
        let newCandidate = Candidate(code: query, text: candidate.text, type: CandidateType.user)
        _ = prependCandidate(candidate: newCandidate)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    func prependCandidate(candidate: Candidate) -> Bool {
        let sql = """
            insert into wb_py_dict(id, wbcode, text, type, query)
            values (
                (select MIN(id) - 1 from wb_py_dict), :code, :text, :type, :code
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
                return true
            }
        }
        sqlite3_finalize(insertStatement)
        insertStatement = nil
        print("errmsg: \(String(cString: sqlite3_errmsg(database)!))")
        return false
    }

    func prependCandidates(candidates: [Candidate]) {
        if candidates.count <= 0 {
            return
        }
        // 2.1 先获取最小id
        let minId = getMinIdFromDictTable()
        // 2.2 添加对应id
        let values = candidates.enumerated().map { (n, candidate) in
            "(\(minId - candidates.count + n), '\(candidate.code)', '\(candidate.text)', '\(candidate.type)', '\(candidate.code)')"
        }.joined(separator: ",")
        let sql = """
            insert into wb_py_dict(id, wbcode, text, type, query)
            values \(values)
        """
        sqlite3_exec(database, sql, nil, nil, nil)
    }

    func updateUserDict(_ dictContent: String) {
        // 1. 先删除之前的用户词库
        sqlite3_exec(database, "delete from wb_py_dict where type = '\(CandidateType.user.rawValue)'", nil, nil, nil)
        // 2. 添加用户词库
        let lines = dictContent.split(whereSeparator: \.isNewline)
        let candidates = lines.map { (line) -> [Candidate] in
            let strs = line.split(whereSeparator: \.isWhitespace)
            if strs.count <= 1 {
                return []
            }
            let code = String(strs.first!)
            let candidateTexts = strs[1...]
            return candidateTexts.map { text in
                Candidate(code: code, text: String(text), type: CandidateType.user)
            }
        }.reduce([] as [Candidate]) { partialResult, cur in
            partialResult + cur
        }
        prependCandidates(candidates: candidates)
        NotificationQueue.default.enqueue(Notification(name: DictManager.userDictUpdated), postingStyle: .whenIdle)
    }

    func getUserCandidates() -> [Candidate] {
        var stmt: OpaquePointer?
        let sql = "select query, text from wb_py_dict where type = '\(CandidateType.user.rawValue)'"
        if sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK {
            var candidates: [Candidate] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(stmt, 0))
                let text = String(cString: sqlite3_column_text(stmt, 1))
                candidates.append(Candidate(code: code, text: text, type: .user))
            }
            sqlite3_finalize(stmt)
            stmt = nil
            return candidates
        }
        sqlite3_finalize(stmt)
        stmt = nil
        return []
    }

    func getUserDictContent() -> String {
        // 获取用户候选词(包括调整顺序的词)
        struct UserDictLine {
            let code: String
            var texts: [String]
        }
        let candidates = getUserCandidates()
        NSLog("[DictManager.exportUserDictToFile] candidates: \(candidates)")
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
            ([dictItem.code] + dictItem.texts).joined(separator: "\t")
        }
        .joined(separator: "\n")
        return content
    }
}
