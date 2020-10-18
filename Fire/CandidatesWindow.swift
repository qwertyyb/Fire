//
//  FireCandidatesWindow.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import SwiftUI
import InputMethodKit

class CandidatesWindow: NSWindow {

    func setCandidates(
        candidates: [Candidate],
        originalString: String,
        topLeft: NSPoint
    ) {
        self.contentView = NSHostingView(rootView: CandidatesView(candidates: candidates, origin: originalString))
        self.setFrameTopLeftPoint(topLeft)
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
        styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        isReleasedWhenClosed = false
    }

    private func transformTopLeft(originalTopLeft: NSPoint) -> NSPoint {
        NSLog("[FireCandidatesWindow] transformTopLeft: \(frame)")

        let screenPadding: CGFloat = 6
        let distance: CGFloat = 3

        var curScreen = NSScreen.main
        // find current screen
        for screen in NSScreen.screens {
            if screen.frame.contains(originalTopLeft) {
                curScreen = screen
                break
            }
        }
        var left = originalTopLeft.x
        var top = originalTopLeft.y - distance
        if curScreen != nil {
            let screen = curScreen!.frame

            if originalTopLeft.x + frame.width > screen.maxX - screenPadding {
                left = screen.maxX - frame.width - screenPadding
            }
            if originalTopLeft.y - frame.height < screen.minY + screenPadding {
                top = screen.minY + frame.height + screenPadding
            }
        }
        return NSPoint(x: left, y: top)
    }

    static let shared = CandidatesWindow()
}
