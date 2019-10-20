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
    private var cursorRect: NSRect?
    let height = CGFloat(54)
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        self.viewsNeedDisplay = true
        self.contentView = view
        styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        isReleasedWhenClosed = false
        backgroundColor = .white
    }
    func updateWindow(cursorRect: NSRect, code: String, candidates: [Candidate], animate: Bool = false) {
//        setFrameOrigin(NSMakePoint(origin.x + 3, origin.y - CGFloat(height) - 3))
        self.cursorRect = cursorRect
        view.updateView(code: code, candidates: candidates)
        orderFront(nil)
    }
    
    func updateNetCandidateView(candidate: Candidate?) {
        view.updateNetCandidateView(candidate: candidate)
    }
    
    func updateFrame(viewWidth: CGFloat, viewHeight: CGFloat) {
        var curScreen = NSScreen.main
        // find current screen
        let origin = cursorRect!.origin
        for screen in NSScreen.screens {
            if screen.frame.contains(origin) {
                curScreen = screen
                break
            }
        }
        var x = origin.x + 3
        var y = origin.y - height - 3
        if curScreen != nil {
            let sf = curScreen!.frame
            if origin.x + viewWidth > sf.width {
                x = sf.width - viewWidth - 3
            }
            if origin.y - viewHeight < 0 {
                y = origin.y + cursorRect!.height + 3
            }
        }
        self.setFrame(NSMakeRect(x, y, viewWidth, viewHeight), display: true)
    }
    
    static let shared = FireCandidatesWindow()
}
