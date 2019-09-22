//
//  FireCandidatesView.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa

class FireCandidatesView: NSStackView {
    
    var inputLabel: NSTextField = NSTextField(labelWithString: "")
    var candidatesView: NSStackView = NSStackView()
    
    var inputController: FireInputController? {
        get {
            if (self.window == nil) { return nil }
            return (self.window as! FireCandidatesWindow).inputController
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .vertical
        alignment = .left
        
        inputLabel.font = NSFont.userFont(ofSize: 18)
        inputLabel.textColor = NSColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        addView(inputLabel, in: .leading)
        
        candidatesView.orientation = .horizontal
        addView(candidatesView, in: .trailing)
        edgeInsets = NSEdgeInsets.init(top: 0, left: 3.0, bottom: 0, right: 3.0)
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    func updateInputLabel () {
        print("label: \((inputController?.originalString(inputController?.client()))!)");
        inputLabel.attributedStringValue = (inputController?.originalString(inputController?.client()))!
    }
    override func clippingResistancePriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority {
        return .defaultLow
    }
    func updateCandidateViews () {
        let candidates = inputController?.candidates(inputController?.client()) as!  [String]
        if (self.window != nil) {
            let window = self.window as! FireCandidatesWindow
            var width = self.getWidth(candidates: candidates)
            width = width > 300 ? width : 300
            window.setFrame(NSRect(x: window.origin.x, y: window.origin.y, width: CGFloat(width), height: CGFloat(window.height)), display: true)
        }
        var index = -1
        let views = candidates.map({ (text) -> NSTextField in
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
    
    private func getWidth(candidates: [String]) -> Int {
        let width = candidates.reduce(0) { (result: Int, item: String) -> Int in
            return result + (item.count + 1) * 20 + 10;
        }
        NSLog("width: \(width)")
        return width
    }
    
}
