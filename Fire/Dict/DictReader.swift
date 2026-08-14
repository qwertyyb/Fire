//
//  DictReader.swift
//  Fire
//
//  Extracted from DictManager.swift: read-only dictionary query logic.
//

import Foundation
import Defaults

final class DictReader {
    private var database: OpaquePointer?
    private var queryStatement: OpaquePointer?

    func bind(database: OpaquePointer?) {
        self.database = database
    }

    func teardown() {
        if queryStatement != nil {
            sqlite3_finalize(queryStatement)
            queryStatement = nil
        }
    }

    func prepare() {
        teardown()
        guard database != nil else { return }
        let sql = getStatementSql()
#if DEBUG
        FireLog.dict.debug("SQL: \(sql.replacingOccurrences(of: "\n", with: " "))")
#endif
        if sqlite3_prepare_v2(database, sql, -1, &queryStatement, nil) == SQLITE_OK {
            FireLog.dict.debug("prepare ok")
        } else if let err = sqlite3_errmsg(database) {
            FireLog.dict.error("prepare fail: \(String(cString: err), privacy: .public)")
        }
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
        // zrank：字面量匹配（:queryRaw，含真实 z）优先于 z 万能键通配命中，
        // 避免用户词编码含 z 时被 ORDER BY query 排到 LIMIT 之外
        let sql = """
            WITH top_texts AS (
                SELECT 
                    text,
                    MIN(query) AS query,
                    MIN(id) AS min_id,
                    MIN(CASE WHEN query = :queryRaw THEN 0 ELSE 1 END) AS zrank
                FROM wb_py_dict
                WHERE query glob :queryLike \(typeFilter) \(gbkFilter)
                  AND text NOT IN (SELECT text FROM blocked_words)  -- 排除屏蔽词
                GROUP BY text
                ORDER BY zrank, query, min_id
                LIMIT :offset, \(candidateCount + 1)
            )
            SELECT 
                (select max(wbcode) from wb_py_dict where text = t.text and query glob :queryLike group by text) as wbcode,
                d.text,
                d.type     AS type,                  -- 假设 type 在组内相同，否则需明确逻辑
                t.query,
                d.spell     AS spell,
                d.pinyin    AS pinyin,
                d.is_gb2312 AS is_gb2312
            FROM wb_py_dict d
            JOIN top_texts t ON d.id = t.min_id
            ORDER BY t.zrank, t.query, t.min_id;
        """
        return sql
    }
}

// MARK: - Candidates

extension DictReader {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy MM dd HH mm ss"
        return f
    }()

    private func replaceTextWithVars(_ text: String) -> String {
        let date = Date()
        let arr = DictReader.dateFormatter.string(from: date).split(separator: " ")
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

    func getCandidates(
        query: String,
        page: Int
    ) -> (candidates: [Candidate], hasNext: Bool) {
        if query.count <= 0 {
            return ([], false)
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
        sqlite3_bind_text(queryStatement,
                          sqlite3_bind_parameter_index(queryStatement, ":queryRaw"),
                          query, -1,
                          SQLITE_TRANSIENT
        )
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
}

// MARK: - Wubi Code

extension DictReader {
    /// 查询文本的五笔编码：单字返回全码，多字按词组规则合成。
    /// 任一字找不到全码时返回 nil。
    func queryWubiCode(_ text: String) -> String? {
        let chars = text.map { String($0) }
        guard !chars.isEmpty else { return nil }

        // ≥4 字规则只用第 1、2、3、末字；其余字数查全部
        let needed: [String]
        switch chars.count {
        case 1, 2, 3:
            needed = chars
        default:
            needed = [chars[0], chars[1], chars[2], chars[chars.count - 1]]
        }

        let unique = Array(Set(needed))
        let map = fetchFullWubiCodes(for: unique)
        func code(at index: Int) -> String? { map[needed[index]] }

        switch chars.count {
        case 1:
            return code(at: 0)
        case 2:
            guard let a = code(at: 0), let b = code(at: 1) else { return nil }
            return String(a.prefix(2)) + String(b.prefix(2))
        case 3:
            guard let a = code(at: 0), let b = code(at: 1), let c = code(at: 2) else { return nil }
            return String(a.prefix(1)) + String(b.prefix(1)) + String(c.prefix(2))
        default:
            guard let a = code(at: 0), let b = code(at: 1),
                  let c = code(at: 2), let d = code(at: 3) else { return nil }
            return String(a.prefix(1)) + String(b.prefix(1))
                + String(c.prefix(1)) + String(d.prefix(1))
        }
    }

    /// 一次查出各字的五笔全码（同字多行时取 length 最长、id 最小）
    private func fetchFullWubiCodes(for chars: [String]) -> [String: String] {
        guard !chars.isEmpty, database != nil else { return [:] }
        let placeholders = Array(repeating: "?", count: chars.count).joined(separator: ", ")
        let sql = """
            select text, wbcode, id from wb_py_dict
            where type = 'wb' and text in (\(placeholders))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = database != nil ? String(cString: sqlite3_errmsg(database)) : "nil"
            FireLog.dict.error("fetchFullWubiCodes prepare fail: \(errMsg, privacy: .public)")
            return [:]
        }
        for (i, char) in chars.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), char, -1, SQLITE_TRANSIENT)
        }

        // text -> (wbcode, length, id)；保留更优的全码
        var best: [String: (code: String, len: Int, id: Int32)] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let text = optString(stmt, 0),
                  let wbcode = optString(stmt, 1) else { continue }
            let id = sqlite3_column_int(stmt, 2)
            let len = wbcode.count
            if let cur = best[text] {
                if len > cur.len || (len == cur.len && id < cur.id) {
                    best[text] = (wbcode, len, id)
                }
            } else {
                best[text] = (wbcode, len, id)
            }
        }
        sqlite3_finalize(stmt)
        return best.mapValues { $0.code }
    }
}

// MARK: - User Dict

extension DictReader {
    private func getUserCandidates() -> [Candidate] {
        let sql = "select query, text from wb_py_dict where type = '\(CandidateType.user.rawValue)'"
        var candidates: [Candidate] = []
        sqliteQuery(database, sql) { stmt in
            guard let code = optString(stmt, 0), let text = optString(stmt, 1) else { return }
            candidates.append(Candidate(code: code, text: text, type: .user))
        }
        return candidates
    }

    func exportUserDictContent() -> String {
        // 获取用户候选词(包括调整顺序的词)
        struct UserDictLine {
            let code: String
            var texts: [String]
        }
        let candidates = getUserCandidates()
        FireLog.dict.debug("exportUserDictContent candidates: \(candidates.count, privacy: .public)")
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

// MARK: - Blocked Words

extension DictReader {
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
}

// MARK: - Export

extension DictReader {
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
}
