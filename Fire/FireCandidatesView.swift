//
//  FireCandidatesView.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa

class FireCandidatesView: NSStackView {
    
    var inputLabel: NSTextField = NSTextField(labelWithString: "kkwkwkw")
    var candidatesView: NSStackView = NSStackView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .vertical
        alignment = .left
        
        inputLabel.font = NSFont.userFont(ofSize: 18)
        addView(inputLabel, in: .leading)
        
        candidatesView.orientation = .horizontal
        addView(candidatesView, in: .trailing)
//        self.updateInputLabel()
//        self.updateCandidateViews()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    func updateInputLabel () {
        inputLabel.stringValue = Fire.shared.inputstr
    }
    override func clippingResistancePriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority {
        return .defaultLow
    }
    func updateCandidateViews () {
        if (self.window != nil) {
            let window = self.window as! FireCandidatesWindow
            var width = self.getWidth()
            width = width > 300 ? width : 300
            window.setFrame(NSRect(x: window.origin.x, y: window.origin.y, width: CGFloat(width), height: CGFloat(window.height)), display: true)
        }
        var index = -1
        let views = Fire.shared.candidatesTexts.map({ (text) -> NSTextField in
            index += 1
            return NSTextField(
                labelWithAttributedString: NSAttributedString(
                    string: "\(index + 1).\(text)",
                    attributes: [
                        NSAttributedString.Key.foregroundColor: index == 0 ? NSColor.red : NSColor.init(red: 0.23, green: 0.23, blue: 0.23, alpha: 1),
                        NSAttributedString.Key.font: NSFont.userFont(ofSize: 20)!
                    ]
                )
            )
        })
        updateInputLabel()
        candidatesView.setViews(views, in: .leading)
    }
    
    private func getWidth() -> Int {
        
        let width = Fire.shared.candidatesTexts.reduce(0) { (result: Int, item: String) -> Int in
            return result + (item.count + 1) * 20 + 10;
        }
        NSLog("width: \(width)")
        return width
    }
    
    func drawCandidateTexts () {
        let texts = Fire.shared.candidatesTexts
        if texts.count <= 0 {
            return
        }
        var prevText = ""
        for index in 1...texts.count {
            let text = NSMutableString(string: "\(index).\(texts[index - 1])")
            text.draw(
                in: NSRect(x: 3 + 48 * prevText.count, y: -4, width: texts[index-1].count * 30 + 10, height: 30),
                withAttributes: [
                    NSAttributedString.Key.font: NSFont.userFont(ofSize: 20)!,
                    NSAttributedString.Key.kern: 1,
                    NSAttributedString.Key.foregroundColor: index == 1 ? NSColor.green :
                        NSColor.init(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
                ]
            )
            prevText += texts[index - 1]
        }
    }
    
}
