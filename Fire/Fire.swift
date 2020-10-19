//
//  Fire.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit
import SQLite3
import Sparkle
import Defaults

let kConnectionName = "Fire_1_Connection"

struct Candidate: Hashable {
    let code: String
    let text: String
    let type: String  // wb | pyg
}

enum CodeMode: Int, CaseIterable, Decodable, Encodable {
    case wubi
    case pinyin
    case wubiPinyin
}

struct NetCandidate: Codable {
    let wbcode: String
    let text: String
    let weight: Int
}

struct CandidatesResponse: Codable {
    let errcode: Int
    let errmsg: String
    let list: [NetCandidate]
}

extension UserDefaults {
    @objc dynamic var codeMode: Int {
        get {
            return integer(forKey: "codeMode")
        }
        set {
            set(newValue, forKey: "codeMode")
        }
    }
}

internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

class Fire: NSObject {
    private var database: OpaquePointer?
    private var queryStatement: OpaquePointer?
    private var preferencesObserver: Defaults.Observation!

    override init() {
        super.init()

        sqlite3_open(Bundle.main.path(forResource: "table", ofType: "sqlite"), &database)
        self.prepareStatement()

        preferencesObserver = Defaults.observe(keys: .codeMode, .candidateCount) { () in
            self.prepareStatement()
        }
    }

    deinit {
        preferencesObserver.invalidate()
    }

    private func getStatementSql() -> String {
        let codeMode = Defaults[.codeMode]
        let tableType = codeMode == .wubiPinyin ? "" : "type = '\(codeMode == .pinyin ? "py" : "wb")' and "
        let candidateCount = Defaults[.candidateCount]
        let sql = """
        select
            case when t2.type = 'wb' then min(t1.code) else max(t1.code) end as code,
            t1.text,
            t2.type
        from
            dict_default t1
            inner join
                (select min(id) as id,
                code, text, type
                from dict_default
                where \(tableType)code like :query
                group by id, text
                order by length(code)) t2
            on t1.text = t2.text and t1.type = 'wb'
        group by t1.text
        order by case when t2.code = :code then t2.id
             when t2.code like :query then 10000000 + t2.id end
        limit :offset, \(candidateCount)
        """
        print(sql)
        return sql
    }

    private func prepareStatement() {
        if sqlite3_prepare_v2(database, getStatementSql(), -1, &queryStatement, nil) == SQLITE_OK {
            print("prepare ok")
            print(sqlite3_bind_parameter_index(queryStatement, ":code"))
            print(sqlite3_bind_parameter_count(queryStatement))
        }
    }

    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    func getCandidates(origin: String = String(), page: Int = 1) -> [Candidate] {
        if origin.count <= 0 {
            return []
        }
        NSLog("get local candidate, origin: \(origin)")
//        var db: OpaquePointer?
        var candidates: [Candidate] = []
        sqlite3_reset(queryStatement)
        sqlite3_clear_bindings(queryStatement)
        sqlite3_bind_text(queryStatement,
                        sqlite3_bind_parameter_index(queryStatement, ":code"),
                        origin, -1,
                        SQLITE_TRANSIENT
        )
        sqlite3_bind_text(queryStatement,
                          sqlite3_bind_parameter_index(queryStatement, ":query"),
                          "\(origin)%", -1,
                          SQLITE_TRANSIENT
        )
        sqlite3_bind_int(queryStatement,
                         sqlite3_bind_parameter_index(queryStatement, ":offset"),
                         Int32((page - 1) * Defaults[.candidateCount])
        )
        let strp = sqlite3_expanded_sql(queryStatement)!
        print(String(cString: strp))
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            let code = String.init(cString: sqlite3_column_text(queryStatement, 0))
            let text = String.init(cString: sqlite3_column_text(queryStatement, 1))
            let type = String.init(cString: sqlite3_column_text(queryStatement, 2))
            let candidate = Candidate(code: code, text: text, type: type)
            candidates.append(candidate)
        }
        return candidates
    }

    static let shared = Fire()
}
