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
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .vertical
        alignment = .left
        
        inputLabel.font = NSFont.userFont(ofSize: 20)
        inputLabel.textColor = NSColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        addView(inputLabel, in: .leading)
        spacing = 3.0
        
        candidatesView.orientation = .horizontal
        addView(candidatesView, in: .trailing)
        edgeInsets = NSEdgeInsets.init(top: 1.5, left: 3.0, bottom: 1.5, right: 3.0)
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    func updateCode (code: String) {
        print("label: \(code)");
        inputLabel.stringValue = code
    }
    override func clippingResistancePriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority {
        return .defaultLow
    }
    private func getCandidateView(candidate: Candidate, index: Int) -> NSTextField {
        let count = inputLabel.stringValue.count
        let code = candidate.code
        NSLog("origin count: \(count), code count: \(code.count)")
        let shownCode = code.count > count ? String(code.suffix(code.count - count)) : ""
        let string = NSMutableAttributedString(string: "\(index+1).\(candidate.text)\(shownCode)", attributes: [
                NSAttributedString.Key.foregroundColor: index == 0 ? NSColor.red : NSColor.init(red: 0.23, green: 0.23, blue: 0.23, alpha: 1),
            NSAttributedString.Key.font: NSFont.userFont(ofSize: 20)!
            ])
        string.setAttributes([
            NSAttributedString.Key.foregroundColor: NSColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8),
                NSAttributedString.Key.font: NSFont.userFont(ofSize: 18)!,
                NSAttributedString.Key.baselineOffset: 1
            ],
            range: NSMakeRange("\(index+1).\(candidate.text)".count, shownCode.count)
        )
        return NSTextField(labelWithAttributedString: string)
    }
    func updateView(code: String, candidates: [Candidate]) {
        updateCode(code: code)
        updateCandidateViews(candidates: candidates)
    }
    func updateCandidateViews (candidates: [Candidate]) {
        if (self.window != nil) {
            let window = self.window as! FireCandidatesWindow
            var width = self.getWidth(candidates: candidates)
            width = width > 100 ? width : 100
            let frame = window.frame
            window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y, width: CGFloat(width), height: CGFloat(window.height)), display: true)
        }
        var index = -1
        let views = candidates.map({ (candidate) -> NSTextField in
            index += 1
            return getCandidateView(candidate: candidate, index: index)
        })
        candidatesView.setViews(views, in: .leading)
    }
    
    private func getWidth(candidates: [Candidate]) -> Int {
        
        let count = inputLabel.stringValue.count
        let width = candidates.reduce(0) { (result: Int, item: Candidate) -> Int in
            let code = item.code
            let shownCode = code.count > count ? String(code.suffix(code.count - count)) : ""
            return result + (item.text.count + 1) * 20 +  shownCode.count * 10 + 8;
        }
        NSLog("width: \(width)")
        return width
    }
    
}
