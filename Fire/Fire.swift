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

let kConnectionName = "Fire_1_Connection"

struct Candidate {
    let code: String
    let text: String
    let type: String  // wb | pyg
}

enum CodeMode {
    case Wubi
    case Pinyin
    case WubiPinyin
}

class Fire: NSObject {
    var codeMode: CodeMode = .WubiPinyin
    var candidateCount: Int = 5
    
    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    func getCandidates(origin: NSAttributedString = NSAttributedString()) -> [Candidate] {
        var db: OpaquePointer?
        var candidates: [Candidate] = []
        let dbPath = Bundle.main.path(forResource: "table", ofType: "sqlite")
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let sql = "select case when t2.type = 'wb' then min(t1.code) else max(t1.code) end as code, t1.text, t2.type from dict_default t1 inner join (select * from dict_default where code like '\(origin.string)%' order by case when code = '\(origin.string)' then id when code like '\(origin.string)%' then 100000000 + id end limit 0, \(candidateCount)) t2 on t1.text = t2.text and t1.type = 'wb' group by t1.text order by case when t2.code = '\(origin.string)' then t2.id when t2.code like '\(origin.string)%' then 10000000 + t2.id end"
            //            NSLog("sql: %@", sql)
            var queryStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &queryStatement, nil) == SQLITE_OK {
                NSLog("list")
                while(sqlite3_step(queryStatement) == SQLITE_ROW) {
                    let code = String.init(cString: sqlite3_column_text(queryStatement, 0))
                    let text = String.init(cString: sqlite3_column_text(queryStatement, 1))
                    let type = String.init(cString: sqlite3_column_text(queryStatement, 2))
                    let candidate = Candidate(code: code, text: text, type: type)
                    NSLog("text \(text)")
                    candidates.append(candidate)
                }
                sqlite3_finalize(queryStatement)
            }
        }
        sqlite3_close(db)
        return candidates
    }

    static let shared = Fire()
}
