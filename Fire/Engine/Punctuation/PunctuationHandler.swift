//
//  PunctuationHandler.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/8.
//

class PunctuationHandler {
    static let pairs: [String: String] = [
        "‘": "’", "“": "”",
        "（": "）", "【": "】",
        "「": "」", "《": "》",
        "『": "』", "〔": "〕",
        
        "'": "'", "\"": "\"",
        "(": ")", "[": "]",
        "{": "}", "<": ">",
        "｛": "｝"
    ]
    
    static func isPair(_ text: String) -> Bool {
        guard text.count == 2,
              let open = text.first,
              let close = text.last else { return false }
        return pairs[String(open)] == String(close)
    }
    
    enum HandleResult {
        case commit(String)
        case candidates([String])
    }
    
    var transformer: any PunctuationTransformer
    
    private var counts: [String: Int] = [:]
    
    init(transformer: any PunctuationTransformer) {
        self.transformer = transformer
    }

    func handle(_ origin: String, config: any EngineConfig) -> HandleResult? {
        guard let result = transformer.transform(origin) else { return nil }
        
        if !config.enablePunctuationAutoPair {
            switch result {
            case .pair(let left, let right):
                // 记录次数，奇数次输出right，偶数资输出left
                let curTimes = counts[origin] ?? 0
                counts[origin] = (curTimes + 1) % 2
                if curTimes % 2 == 0 {
                    return .commit(left)
                }
                return .commit(right)
            case .candidates(let list):
                return .candidates(list)
            case .commit(let text):
                return .commit(text)
            }
        }
        switch result {
        case .pair(let left, let right):
            return .commit(left + right)
        case .commit(let text):
            return .commit(text + (Self.pairs[text] ?? ""))
        case .candidates(let list):
            return .candidates(list.map({ text in
                text + (Self.pairs[text] ?? "")
            }))
        }
    }
}
