//
//  EngineStore.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/3.
//

final class EngineStore {
    static let shared = EngineStore()
    
    private static let maxRecentCount = 20
    
    var recentCommittedTexts: [String] = []
    
    func recordCommittedText(_ text: String) {
        recentCommittedTexts.append(text)
        if recentCommittedTexts.count > Self.maxRecentCount {
            recentCommittedTexts.removeFirst()
        }
    }
    func getRecentCommitedTexts(_ count: Int) -> String {
        recentCommittedTexts.suffix(count).joined()
    }
}
