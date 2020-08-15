//
//  mode.swift
//  Fire
//
//  Created by 虚幻 on 2020/8/15.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Cocoa

var tipsWindow: NSWindow?
var hideTipsWindowTimer: Timer?

func showTips(_ text: String, frame: NSRect) {
    NSLog("[utils] showTips: \(frame)")
    hideTipsWindowTimer?.invalidate()
    if (tipsWindow?.isVisible ?? false) {
        tipsWindow?.close()
    }
    let window = NSWindow()
    window.styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)

    let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = NSTextAlignment.center
    let textField = NSTextField(labelWithAttributedString: NSAttributedString(
        string: text,
        attributes: [
            NSAttributedString.Key.font: NSFont.userFont(ofSize: 20)!,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ]
    ))
    textField.setFrameSize(NSMakeSize(30, 24))
    textField.alignment = .center
    window.contentView?.addSubview(textField)
    window.isReleasedWhenClosed = false
    window.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel() + 2))
    
    window.setFrame(NSMakeRect(frame.origin.x, frame.origin.y, 30, 24), display: true)
    window.orderFront(nil)
    tipsWindow = window
    hideTipsWindowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (timer) in
        tipsWindow?.close()
    }
    
}

