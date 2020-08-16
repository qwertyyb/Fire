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

let kConnectionName = "Fire_1_Connection"

struct Candidate {
    let code: String
    let text: String
    let type: String  // wb | pyg
}

enum CodeMode: Int {
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

class Fire: NSObject {
    var codeMode: CodeMode = .wubiPinyin
    var candidateCount: Int = 5
    var cloudinput: Bool = false

    override init() {
        UserDefaults.standard.register(defaults: ["codeMode": 2, "candidateCount": 5, "cloudinput": false])
        codeMode = CodeMode(rawValue: UserDefaults.standard.integer(forKey: "codeMode"))!
        candidateCount = UserDefaults.standard.integer(forKey: "candidateCount")
        cloudinput = UserDefaults.standard.bool(forKey: "cloudinput")
        super.init()
        UserDefaults.standard.addObserver(
            self, forKeyPath: "codeMode", options: [.new, .old, .initial], context: nil)
        UserDefaults.standard.addObserver(
            self, forKeyPath: "candidateCount", options: [.new, .old, .initial], context: nil)
        UserDefaults.standard.addObserver(
            self, forKeyPath: "cloudinput", options: [.new, .old, .initial], context: nil)
    }
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        let newVal = change![NSKeyValueChangeKey.newKey]
        if keyPath == "codeMode" {
            if let rawValue = newVal as? Int { codeMode = CodeMode(rawValue: rawValue)! }
        } else if keyPath == "candidateCount" {
            if let count = newVal as? Int { candidateCount = count }
        } else if keyPath == "cloudinput" {
            if let cloud = newVal as? Bool { cloudinput = cloud }
        }
    }

    private func getQuerySql(code: String = "", page: Int = 1) -> String {
        let tableType = codeMode == .wubiPinyin ? "" : "type = '\(codeMode == .pinyin ? "py" : "wb")' and "
        // swiftlint:disable:next line_length
        let sql = "select case when t2.type = 'wb' then min(t1.code) else max(t1.code) end as code, t1.text, t2.type from dict_default t1 inner join (select min(id) as id, code, text, type from dict_default where \(tableType)code like '\(code)%' group by id, text order by length(code)) t2 on t1.text = t2.text and t1.type = 'wb' group by t1.text order by case when t2.code = '\(code)' then t2.id when t2.code like '\(code)%' then 10000000 + t2.id end limit \((page - 1) * candidateCount), \(candidateCount)"
        print(sql)
        return sql
    }

    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    func getCandidates(origin: String = String(), page: Int = 1) -> [Candidate] {
        if origin.count <= 0 {
            return []
        }
        NSLog("get local candidate, origin: \(origin)")
        var db: OpaquePointer?
        var candidates: [Candidate] = []
        let dbPath = Bundle.main.path(forResource: "table", ofType: "sqlite")
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let sql = getQuerySql(code: origin, page: page)
            var queryStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &queryStatement, nil) == SQLITE_OK {
//                NSLog("list")
                while sqlite3_step(queryStatement) == SQLITE_ROW {
                    let code = String.init(cString: sqlite3_column_text(queryStatement, 0))
                    let text = String.init(cString: sqlite3_column_text(queryStatement, 1))
                    let type = String.init(cString: sqlite3_column_text(queryStatement, 2))
                    let candidate = Candidate(code: code, text: text, type: type)
//                    NSLog("text \(text)")
                    candidates.append(candidate)
                }
                sqlite3_finalize(queryStatement)
            }
        }
        sqlite3_close(db)
        return candidates
    }

    func getCandidateFromNetwork(origin: String, sender: (IMKTextInput & NSObjectProtocol)!) {
        if origin.count != 4 { return }
        URLSession.shared.dataTask(
            with: URL.init(string: "http://localhost:8000/dict/candidates?origin=" + origin)!
        ) { (data, _, error) in
            if error != nil {
                print(error!)
                return
            }
            guard let res = try? JSONDecoder().decode(CandidatesResponse.self, from: data!) else { return }
            let candidates = res.list.map { (netCandidate) -> Candidate in
                return Candidate(code: netCandidate.wbcode, text: netCandidate.text, type: "wb")
            }
//            print(res.list)
            NotificationCenter.default.post(Notification.init(
                name: Notification.Name(
                    rawValue: "NetCandidatesUpdate-\(sender.bundleIdentifier() ?? "Fire")"),
                    object: candidates,
                    userInfo: nil
                )
            )
        }.resume()
    }

    static let shared = Fire()
}
