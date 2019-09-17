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
    private var view: FireCandidatesView
    private var client: Any?
    let height = 54
    var origin: NSPoint {
        get {
            let ptr = UnsafeMutablePointer<NSRect>.allocate(capacity: 1)
            ptr.pointee = NSRect()
            (client as! IMKTextInput & NSObjectProtocol).attributes(forCharacterIndex: 0, lineHeightRectangle: ptr)
            let rect = ptr.pointee
            return NSPoint(x: rect.origin.x, y: rect.origin.y - CGFloat(height))
        }
    }
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        view = FireCandidatesView()
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        self.viewsNeedDisplay = true
        isReleasedWhenClosed = false
        self.contentView = view
        styleMask = .init(arrayLiteral: .borderless)
        
    }
    func setClient(_ client: Any!) {
        self.client = client
    }
    func hide() {
        close()
    }
    func updateCondidates() {
        view.updateCandidateViews()
        orderFront(nil)
    }
}
