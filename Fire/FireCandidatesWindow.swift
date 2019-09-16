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
    var view: FireCandidatesView
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        view = FireCandidatesView()
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = .floating
//        self.titleVisibility = .hidden
        self.viewsNeedDisplay = true
        isReleasedWhenClosed = false
        self.contentView = view
        styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        
    }
    func show(sender: IMKTextInput & NSObjectProtocol) {
//        var rect = NSRect()
        let ptr = UnsafeMutablePointer<NSRect>.allocate(capacity: 1)
        ptr.pointee = NSRect()
        sender.attributes(forCharacterIndex: 0, lineHeightRectangle: ptr)
        var rect = ptr.pointee
        if Fire.shared.inputstr == "" {
            rect = NSZeroRect
        }
        
        setFrame(NSRect(x: rect.origin.x, y: rect.origin.y - 60, width: 300, height: 60), display: true)
        view.needsDisplay = true
        orderFront(nil)
    }
    func hide() {
        close()
    }
    func updateCondidates() {
        view.needsDisplay = true
        orderFront(nil)
    }
}
