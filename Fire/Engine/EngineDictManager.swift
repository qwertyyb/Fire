//
//  EngineDictManager.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/3.
//

protocol EngineDictManager {
    func query(_ origin: String, page: Int) -> (candidates: [Candidate], hasNext: Bool)
    
    func queryWubiCode(_ text: String) -> String?
    
    func setCandidateToFirst(_ origin: String, candidate: Candidate)
    
    // 屏蔽候选词
    func blockCandidate(_ candidate: Candidate)
    
    func isBlocked(_ text: String) -> Bool
    
    func unblockText(_ text: String)
    
    // 添加用户词
    func addUserText(origin: String, text: String)
}
