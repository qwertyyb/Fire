//
//  types.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Defaults

enum CandidatesDirection: Int, Decodable, Encodable {
    case vertical
    case horizontal
}

extension Defaults.Keys {
    static let candidatesDirection = Key<CandidatesDirection>(
        "candidatesDirection",
        default: CandidatesDirection.horizontal
    )
    static let showCodeInWindow = Key<Bool>("showCodeInWindow", default: true)
    static let wubiCodeTip = Key<Bool>("wubiCodeTip", default: true)
    static let wubiAutoCommit = Key<Bool>("wubiAutoCommit", default: false)
    static let candidateCount = Key<Int>("candidateCount", default: 5)
    static let codeMode = Key<CodeMode>("codeMode", default: CodeMode.wubiPinyin)
    //            ^            ^         ^                ^
    //           Key          Type   UserDefaults name   Default value
}

enum InputMode {
    case zhhans
    case enUS
}

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

let punctution: [String: String] = [
    ",": "，",
    ".": "。",
    "/": "、",
    ";": "；",
    "'": "‘",
    "[": "［",
    "]": "］",
    "`": "｀",
    "!": "！",
    "@": "‧",
    "#": "＃",
    "$": "￥",
    "%": "％",
    "^": "……",
    "&": "＆",
    "*": "×",
    "(": "（",
    ")": "）",
    "-": "－",
    "_": "——",
    "+": "＋",
    "=": "＝",
    "~": "～",
    "{": "｛",
    "\\": "、",
    "|": "｜",
    "}": "｝",
    ":": "：",
    "\"": "“",
    "<": "《",
    ">": "》",
    "?": "？"
]
