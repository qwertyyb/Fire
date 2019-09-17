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

let kConnectionName = "Fire_2_Connection"

class Fire: NSObject {
    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    
    let candidates: FireCandidatesWindow = FireCandidatesWindow()
    
    var inputstr: String = "" {
        didSet {
            if inputstr != oldValue {
                updateCandidatesText()
            }
        }
    }
    var candidatesTexts: [String] = []
    
    func updateCandidatesText() {
        var db: OpaquePointer?
        self.candidatesTexts = []
        if sqlite3_open("/Users/marchyang/dict.sqlite", &db) == SQLITE_OK {
            let sql = "select distinct full, text from dict where simple like '\(self.inputstr)%' or full like '\(self.inputstr)%' order by weight desc limit 0, 10"
            NSLog("sql: %@", sql)
            var queryStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &queryStatement, nil) == SQLITE_OK {
                while(sqlite3_step(queryStatement) == SQLITE_ROW) {
                    let text = String.init(cString: sqlite3_column_text(queryStatement, 1))
                    self.candidatesTexts.append(text)
                }
                self.candidates.updateCondidates()
            }
        }
    }

    static let shared = Fire()
}
