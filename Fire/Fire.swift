//
//  Fire.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

let kConnectionName = "Fire_1_Connection"

class Fire: NSObject {
    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    
    let candidates: FireCandidatesWindow = FireCandidatesWindow()
    
    var inputstr: String = ""
    var candidatesTexts: [String] = ["我", "J", "W", "W", "Q","Q"]
    override init() {
//        candidates = FireCondidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType:kIMKSubList)
//        candidate.setDismissesAutomatically(false)
    }

    static let shared = Fire()
}
