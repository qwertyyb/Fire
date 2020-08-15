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
    let height = CGFloat(56)
    private var inputController: FireInputController?
    
    private func getOriginRect() -> NSRect {
        let ptr = UnsafeMutablePointer<NSRect>.allocate(capacity: 1)
        ptr.pointee = NSRect()
        self.inputController?.client().attributes(forCharacterIndex: 0, lineHeightRectangle: ptr)
        let rect = ptr.pointee
        print("[FireCandidatesWindow] origin: \(rect)")
        let origin = NSMakeRect(rect.origin.x, rect.origin.y, rect.width, rect.height)
        ptr.deallocate()
        return origin
    }
    
    func setInputController(_ inputController: FireInputController) {
        self.inputController = inputController
    }
    
    func refresh() {
        NSLog("[FireCandidatesWindow] refresh")
        self.cursorRect = getOriginRect()
        view.updateView(
            code: inputController!.originalString(nil)!.string,
            candidates: inputController!.candidates(nil) as! [Candidate]
        )
        orderFront(nil)
    }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        self.viewsNeedDisplay = true
        self.contentView = view
        styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        isReleasedWhenClosed = false
        backgroundColor = .init(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
    }
    
    func updateNetCandidateView(candidate: Candidate?) {
        view.updateNetCandidateView(candidate: candidate)
    }
    
    func resizeRectFitContentView(_ frame: NSRect) {
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
            if origin.x + frame.width > sf.width {
                x = sf.width - frame.width - 3
            }
            if origin.y - frame.height < 0 {
                y = origin.y + cursorRect!.height + 3
            }
        }
        self.setFrame(NSMakeRect(x, y, frame.width, frame.height), display: true)
    }
    
    static let shared = FireCandidatesWindow()
}
