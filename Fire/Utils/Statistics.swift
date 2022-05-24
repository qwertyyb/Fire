//
//  Statistics.swift
//  Fire
//
//  Created by 虚幻 on 2022/5/22.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import SQLite

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
        guard let db = self.db, let candidate = notification.userInfo?["candidate"] as? Candidate else {
            return
        }
        if candidate.isPlaceholder { return }
        _ = try? db.run(data.insert(
            text <- candidate.text,
            type <- candidate.type,
            code <- candidate.code,
            createdAt <- Date()
        ))
        NotificationCenter.default.post(name: Statistics.updated, object: nil)
    }

    func query() -> [Row] {
        guard let res = try? db.prepare(data.order(createdAt.desc)) else {
            return []
        }
        let list = Array(res)
        return list
    }

    func queryCountByDate() -> [DateCount] {
        guard let stmt = try? db.prepare(
            """
            select * from
                (select date(createdAt, 'localtime') as date, sum(length(text)) as count from data group by date(createdAt))
            order by date desc limit 0, 5
            """
        ) else {
            return []
        }
        let results = stmt.map { row -> DateCount in
            return DateCount(count: row[1] as? Int64 ?? 0, date: row[0] as? String ?? "")
        }
        NSLog("[Statistics] queryCountByDate: \(results)")
        return results.sorted { prev, next in
            return next.date > prev.date
        }
    }

    func queryTotalCount() -> Int64 {
        guard let stmt = try? db.prepare(
            "select sum(length(text)) as total from data"
        ) else {
            return 0
        }
        for row in stmt {
            return row[0] as? Int64 ?? 0
        }
        return 0
    }

    func clear() {
        _ = try? db.run(data.delete())
        NotificationCenter.default.post(name: Statistics.updated, object: nil)
    }

    private var db: Connection!
    private let data = Table("data")
    private let id = Expression<Int64>("id")
    private let text = Expression<String>("text")
    private let type = Expression<String>("type")
    private let code = Expression<String>("code")
    private let createdAt = Expression<Date>("createdAt")

    private func initDB() {
        let path = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory, .userDomainMask, true
        ).first! + "/" + Bundle.main.bundleIdentifier!

        // create parent directory iff it doesn’t exist
        try? FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )

        if let connection = try? Connection("\(path)/statistics.sqlite3") {
            db = connection

            _ = try? db.run(data.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(text)
                t.column(type)
                t.column(code)
                t.column(createdAt, defaultValue: Date())
            })
        }
    }
}
