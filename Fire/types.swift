//
//  types.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Defaults
import Sparkle

enum CandidatesDirection: Int, Decodable, Encodable {
    case vertical
    case horizontal
}

enum InputModeTipWindowType: Int, Decodable, Encodable {
    case followInput
    case centerScreen
    case none
}

extension Defaults.Keys {
    static let zKeyQuery = Key<Bool>("zKeyQuery", default: true)
    static let candidatesDirection = Key<CandidatesDirection>(
        "candidatesDirection",
        default: CandidatesDirection.horizontal
    )
    static let inputModeTipWindowType = Key<InputModeTipWindowType>(
        "inputModeTipWindowType",
        default: InputModeTipWindowType.centerScreen
    )
    static let showCodeInWindow = Key<Bool>("showCodeInWindow", default: true)
    static let wubiCodeTip = Key<Bool>("wubiCodeTip", default: true)
    static let wubiAutoCommit = Key<Bool>("wubiAutoCommit", default: false)
    static let candidateCount = Key<Int>("candidateCount", default: 5)
    static let codeMode = Key<CodeMode>("codeMode", default: CodeMode.wubiPinyin)
    static let toggleInputModeKey = Key<NSEvent.ModifierFlags.RawValue>("toggleInputModeKey",
        default: NSEvent.ModifierFlags.shift.rawValue)
    static let wbTablePath = Key<String>(
        "wbTableURL",
        default: Bundle.main.resourceURL?.appendingPathComponent("wb_table.txt").path
            ?? "")
    static let pyTablePath = Key<String>(
        "pyTableURL",
        default: Bundle.main.resourceURL?.appendingPathComponent("py_table.txt").path
            ?? "")
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
    let type: String  // wb | py
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

protocol ToastWindowProtocol {
    func show(_ text: String, position: NSPoint)
}
