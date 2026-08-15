//
//  Candidate.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation

enum CandidateType: String, CaseIterable {
    case wb // 五笔
    case py // 拼音
    case user // 用户词库
    case emoji // 内置 emoji（关键词联想）
    case placeholder // 运行时类型，无匹配时表示占位
    case unknown // 未知类型，用于安全解析数据库记录
}

struct Candidate: Hashable {
    let code: String
    let text: String
    let type: CandidateType
    let label: String
    // 拆字字根（如 〈氵工〉）
    let spelling: String?
    // 拼音
    let pinyin: String?

    init(code: String, text: String, type: CandidateType, label: String? = nil, spelling: String? = nil, pinyin: String? = nil) {
        self.code = code
        self.text = text
        self.type = type
        self.label = label ?? text
        self.spelling = spelling
        self.pinyin = pinyin
    }
}
