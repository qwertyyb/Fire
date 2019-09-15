//
//  FireCandidatesView.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa

class FireCandidatesView: NSView {
    
    var inputLabel: NSText?
    

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.set()
        NSBezierPath.fill(self.bounds)
        
        let inputstr = NSMutableString(string: Fire.shared.inputstr)
//        let inputstr = NSText()
//        inputstr.string = Fire.shared.inputstr
//        inputstr.setTextColor(NSColor.black, range: NSMakeRange(0, Fire.shared.inputstr.count))
//        inputstr.drawsBackground = false
//        inputstr.draw(NSRect(x: 3, y: 3, width: self.bounds.width, height: self.bounds.height * 0.5 - 5))
        inputstr.draw(in: NSRect(x: 3, y: 30, width: self.bounds.width, height: self.bounds.height * 0.5 - 5), withAttributes:[NSAttributedString.Key.font: NSFont.userFont(ofSize: 18)!])
        drawCandidateTexts()
//        inputLabel = NSText(frame: NSRect(x: 10, y: 10, width: self.bounds.width, height: self.bounds.height / 2 - 5))
//        inputLabel?.string = Fire.shared.inputstr
//        addSubview(inputLabel!)
        
        // Drawing code here.
    }
    
    func drawCandidateTexts () {
        let texts = Fire.shared.candidatesTexts
        for index in 1...texts.count {
            let text = NSMutableString(string: "\(index). \(texts[index - 1])")
            text.draw(in: NSRect(x: 3 + 40 * (index - 1), y: 0, width: 36, height: Int(self.bounds.height * 0.5)), withAttributes: [NSAttributedString.Key.font: NSFont.userFont(ofSize: 16)!])
        }
    }
    
}
