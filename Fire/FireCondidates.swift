//
//  FireCondidates.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

class FireCondidates: IMKCandidates {

    override func selectedCandidateString() -> NSAttributedString! {
        return NSAttributedString(string: "我是")
    }
}
