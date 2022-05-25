//
//  Statistics.swift
//  Fire
//
//  Created by 虚幻 on 2022/5/22.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import SQLite3
import Defaults

struct DateCount: Hashable {
    let count: Int64
    let date: String
}

class Statistics {
    static let shared = Statistics()

    static let updated = Notification.Name("Statistics.updated")

    init() {
        NSLog("[Statistics] init")
        NotificationCenter.default
            .addObserver(self, selector: #selector(listener), name: Fire.candidateInserted, object: nil)
        initDB()
    }

    @objc func listener(notification: Notification) {
        NSLog("[Statistics] listener: \(notification)")
        guard let candidate = notification.userInfo?["candidate"] as? Candidate else {
            return
        }
        if !Defaults[.enableStatistics] {
            return
        }
        if candidate.isPlaceholder { return }
        let sql = "insert into data(text, type, code, createdAt) values (:text, :type, :code, :createdAt)"
        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &insertStatement, nil) == SQLITE_OK {
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            sqlite3_bind_text(insertStatement,
                              sqlite3_bind_parameter_index(insertStatement, ":text"),
                              candidate.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement,
                              sqlite3_bind_parameter_index(insertStatement, ":type"),
                              candidate.type, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement,
                              sqlite3_bind_parameter_index(insertStatement, ":code"),
                              candidate.code, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement,
                              sqlite3_bind_parameter_index(insertStatement, ":createdAt"),
                              format.string(from: Date()), -1, SQLITE_TRANSIENT)

            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
                insertStatement = nil
            } else {
                print("errmsg: \(String(cString: sqlite3_errmsg(database)!))")
            }
        } else {
            print("prepare_errmsg: \(String(cString: sqlite3_errmsg(database)!))")
        }
        NotificationCenter.default.post(name: Statistics.updated, object: nil)
    }

    func queryCountByDate() -> [DateCount] {
        var queryStatement: OpaquePointer?
        let sql = """
            select date, count from
                (select
                    date(createdAt, 'localtime') as date,
                    sum(length(text)) as count
                from data group by date(createdAt))
            order by date desc limit 0, 5
        """
        if sqlite3_prepare_v2(database, sql, -1, &queryStatement, nil) == SQLITE_OK {
            var results: [DateCount] = []
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let date = String(cString: sqlite3_column_text(queryStatement, 0))
                let count = sqlite3_column_int64(queryStatement, 1)
                let dateCount = DateCount(count: count, date: date)
                results.append(dateCount)
            }
            return results.sorted { prev, next in
                return next.date > prev.date
            }
        } else {
            return []
        }
    }

    func queryTotalCount() -> Int64 {
        let sql = "select sum(length(text)) as total from data"
        var queryStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &queryStatement, nil) == SQLITE_OK
            && sqlite3_step(queryStatement) == SQLITE_ROW {
            let count = sqlite3_column_int64(queryStatement, 0)
            return count
        }
        return 0
    }

    func clear() {
        let sql = "delete * from data"
        sqlite3_exec(database, sql, nil, nil, nil)
        NotificationCenter.default.post(name: Statistics.updated, object: nil)
    }
    private var database: OpaquePointer?

    private func initDB() {
        let path = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory, .userDomainMask, true
        ).first! + "/" + Bundle.main.bundleIdentifier! + "/statistics.sqlite3"

        // create parent directory iff it doesn’t exist
        try? FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )

        sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE, nil)
    }
}
