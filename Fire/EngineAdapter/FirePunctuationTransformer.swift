//
//  FirePunctuationTransformer.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/8.
//
import Defaults

let defaultPunctuationMapping: [String: PunctuationMapping] = [
    ",": .commit("，"),
    ".": .commit("。"),
    "/": .commit("、"),
    ";": .commit("；"),
    "[": .candidates(["[", "【", "「", "『", "〔"]),
    "]": .candidates(["]", "】", "」", "』", "〕"]),
    "`": .commit("`"),
    "!": .commit("！"),
    "@": .commit("@"),
    "#": .commit("#"),
    "$": .commit("￥"),
    "%": .commit("%"),
    "^": .candidates(["^", "……"]),
    "&": .commit("&"),
    "*": .commit("*"),
    "(": .commit("（"),
    ")": .commit("）"),
    "-": .commit("-"),
    "_": .commit("——"),
    "+": .commit("+"),
    "=": .commit("="),
    "~": .commit("～"),
    "{": .candidates(["{", "「", "｛"]),
    "}": .candidates(["}", "」", "｝"]),
    "\\": .commit("、"),
    "|": .commit("｜"),
    ":": .commit("："),
    "\"": .pair(left: "“", right: "”"),
    "'": .pair(left: "‘", right: "’"),
    "<": .commit("《"),
    ">": .commit("》"),
    "?": .commit("？")
]

enum PunctuationMappingStore {
    static func resolvedMapping(
        mappingType: PunctuationMappingType,
        customMapping: [String: PunctuationMapping]
    ) -> [String: PunctuationMapping] {
        switch mappingType {
        case .default:
            return defaultPunctuationMapping
        case .custom:
            return customMapping
        }
    }

    static func transform(_ origin: String) -> PunctuationMapping? {
        transform(
            origin,
            mode: Defaults[.punctuationMode],
            mappingType: Defaults[.punctuationMappingType],
            customMapping: Defaults[.punctuationCustomMapping]
        )
    }

    static func transform(
        _ origin: String,
        mode: PunctuationMode,
        mappingType: PunctuationMappingType,
        customMapping: [String: PunctuationMapping]
    ) -> PunctuationMapping? {
        switch mode {
        case .enUs:
            guard defaultPunctuationMapping[origin] != nil else { return nil }
            return .commit(origin)
        case .zhhans:
            return resolvedMapping(mappingType: mappingType, customMapping: customMapping)[origin]
        }
    }
}

struct FirePunctuationTransformer: PunctuationTransformer {
    func transform(_ origin: String) -> PunctuationMapping? {
        PunctuationMappingStore.transform(origin)
    }
}
