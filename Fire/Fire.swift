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
}

class Fire: NSObject {
    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    func getCandidates(origin: NSAttributedString = NSAttributedString()) -> [Candidate] {
        var db: OpaquePointer?
        var candidates: [Candidate] = []
        let dbPath = Bundle.main.path(forResource: "dict", ofType: "sqlite")
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let sql = "select distinct code, text from wb_dict_86 where code like '\(origin.string)%' order by id asc limit 0, 10"
            //            NSLog("sql: %@", sql)
            var queryStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &queryStatement, nil) == SQLITE_OK {
                while(sqlite3_step(queryStatement) == SQLITE_ROW) {
                    let code = String.init(cString: sqlite3_column_text(queryStatement, 0)).suffix(4 - origin.length)
                    let text = String.init(cString: sqlite3_column_text(queryStatement, 1))
                    let candidate = Candidate(code: String(code), text: text)
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
