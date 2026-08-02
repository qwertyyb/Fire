//
//  InputContext.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//

protocol InputContext {
    var inputMode: InputMode { get set }
    
    var origin: String { get set }
    var candidates: [Candidate] { get set }
    var hasNext: Bool { get set }
    var curPage: Int { get set }
    var selectedIndex: Int { get set }
    
    func prevPage()
    
    func nextPage()
    
    func getTextBefore(_ count: Int) -> String
    
    func commit(_ text: String)
    func commitCandidate(_ candidate: Candidate, confirmed: Bool)
    
    func moveCursor(_ offset: Int)
}

