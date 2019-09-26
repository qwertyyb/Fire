//
//  FireCandidatesWindow.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

class FireCandidatesWindow: NSWindow {
    private var view: FireCandidatesView = FireCandidatesView()
    private var client: Any?
    let height = 54
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        self.viewsNeedDisplay = true
        self.contentView = view
        styleMask = .init(arrayLiteral: .borderless)
        isReleasedWhenClosed = false
        backgroundColor = .white
    }
    func updateWindow(origin: NSPoint, code: String, candidates: [Candidate]) {
        setFrameOrigin(NSMakePoint(origin.x + 3, origin.y - CGFloat(height) - 3))
        view.updateView(code: code, candidates: candidates)
        orderFront(nil)
    }
    
    static let shared = FireCandidatesWindow()
}
