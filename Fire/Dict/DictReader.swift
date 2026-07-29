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

    func prepare() {
        teardown()
        guard database != nil else { return }
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

    // replaceTextWithVars 中使用的 DateFormatter 提为 static let，避免重复创建
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

    /// 字面量匹配 pattern（不把 z 换成 ?），供 SQL zrank 优先用户词等真实含 z 的编码
    private func getQueryRaw(_ origin: String) -> String {
        if origin.isEmpty {
            return origin
        }
        let suffix = Defaults[.enableExactMatch] ? "" : "*"
        return origin + suffix
    }

    func punctuationCandidates(query: String) -> [Candidate] {
        let text = query.count == 1 ? query : String(query.suffix(query.count - 1))
        return [Candidate(
            code: query,
            text: text,
            type: .placeholder,
            label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)")]
    }

    func getCandidates(
        query: String,
        page: Int,
        tempEnTrigger: Character
    ) -> (candidates: [Candidate], hasNext: Bool) {
        if query.count <= 0 {
            return ([], false)
        }
        if query.first == tempEnTrigger {
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
        let queryRaw = getQueryRaw(query)
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
                          queryRaw, -1,
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
