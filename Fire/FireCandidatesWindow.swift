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
    let height = CGFloat(56)

    func setCandidates(candidates: [Candidate], originalString: String) {
        self.view.updateView(
            code: originalString,
            candidates: candidates
        )
        self.orderFront(nil)
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
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
        NSLog("[FireCandidatesWindow] resizeRectFitContentView: \(frame)")
        var curScreen = NSScreen.main
        // find current screen
        let originalFrame = self.frame
        let origin = originalFrame.origin
        for screen in NSScreen.screens {
            if screen.frame.contains(origin) {
                curScreen = screen
                break
            }
        }
        var left = origin.x + 3
        var bottom = origin.y - height - 3
        if curScreen != nil {
            let screen = curScreen!.frame
            if origin.x + frame.width > screen.width {
                left = screen.width - frame.width - 3
            }
            if origin.y - frame.height < 0 {
                bottom = origin.y + originalFrame.height + 3
            }
        }
        self.setFrame(NSRect(x: left, y: bottom, width: frame.width, height: frame.height), display: true)
    }

    static let shared = FireCandidatesWindow()
}
