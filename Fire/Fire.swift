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
    var candidatesTexts: [String] = ["我", "J", "W", "W", "Q","Q"]
    override init() {
//        candidates = FireCondidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType:kIMKSubList)
//        candidate.setDismissesAutomatically(false)
    }
    
    func updateCandidatesText() {
        var db: OpaquePointer?
        self.candidatesTexts = []
        if sqlite3_open("/Users/marchyang/dict.sqlite", &db) == SQLITE_OK {
            let sql = "select * from dict where full like '\(self.inputstr)%' order by weight desc limit 0, 100"
            NSLog("sql: %@", sql)
            var queryStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &queryStatement, nil) == SQLITE_OK {
                while(sqlite3_step(queryStatement) == SQLITE_ROW) {
                    //第三步
//                    let id = sqlite3_column_int(queryStatement, 0)
//
//                    let queryResultName = sqlite3_column_text(queryStatement, 1)
//                    let name = String(cString: queryResultName!)
//                    let weight = sqlite3_column_int(queryStatement, 2)
//                    let price = sqlite3_column_double(queryStatement, 3)
                    let text = String.init(cString: sqlite3_column_text(queryStatement, 3))
                    self.candidatesTexts.append(text)
                    
//                    resultLabel.text = "id: \(id), name: \(name), weight: \(weight), price: \(price)"
                }
                self.candidates.updateCondidates()
            }
        }
    }

    static let shared = Fire()
}
