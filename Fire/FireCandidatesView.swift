//
//  FireCandidatesView.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
// 

import Cocoa

class FireCandidatesView: NSStackView {

    var originView: NSTextField = NSTextField(labelWithString: "")
    var candidatesView: NSStackView = NSStackView()
    var spinView: NSProgressIndicator = NSProgressIndicator()
    var topStackView = NSStackView()
    var netCandidate = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .vertical
        alignment = .left
        spacing = 3.0

        topStackView.alignment = .centerY

        originView.font = NSFont.labelFont(ofSize: 20)
        originView.textColor = NSColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        topStackView.addView(originView, in: .leading)

        spinView.style = .spinning
        spinView.controlSize = .small
        topStackView.addView(spinView, in: .center)

        addView(topStackView, in: .leading)

        candidatesView.orientation = .horizontal
        addView(candidatesView, in: .trailing)
        edgeInsets = NSEdgeInsets.init(top: 3, left: 12, bottom: 6, right: 12)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    override func clippingResistancePriority(
        for orientation: NSLayoutConstraint.Orientation
    ) -> NSLayoutConstraint.Priority {
        return .defaultLow
    }
    private func getShownCode(candidate: Candidate, origin: String) -> String {
        if candidate.type == "py" {
            return "(\(candidate.code))"
        }
        return candidate.code.hasPrefix(origin) && candidate.code.count > origin.count
            ? "~\(String(candidate.code.suffix(candidate.code.count - origin.count)))" : ""
    }
    private func getCandidateView(candidate: Candidate, index: Int, origin: String) -> NSTextField {
        let shownCode = getShownCode(candidate: candidate, origin: origin)
        let string = NSMutableAttributedString(string: "\(index+1).\(candidate.text)\(shownCode)", attributes: [
            NSAttributedString.Key.foregroundColor: index == 0
                ? NSColor(red: 0.863, green: 0.078, blue: 0.235, alpha: 1)
                : NSColor.init(red: 0.23, green: 0.23, blue: 0.23, alpha: 1),
                NSAttributedString.Key.font: NSFont.labelFont(ofSize: 20)
            ])
        string.setAttributes([
            NSAttributedString.Key.foregroundColor: NSColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8),
                NSAttributedString.Key.font: NSFont.userFont(ofSize: 18)!,
                NSAttributedString.Key.baselineOffset: 1
            ],
            range: NSRange(location: "\(index+1).\(candidate.text)".count, length: shownCode.count)
        )
        return NSTextField(labelWithAttributedString: string)
    }
    private func getCandidateViews (candidates: [Candidate], origin: String) -> [NSTextField] {
        var index = -1
        return candidates.map({ (candidate) -> NSTextField in
            index += 1
            return getCandidateView(candidate: candidate, index: index, origin: origin)
        })
    }
    func updateView(code: String, candidates: [Candidate]) {
        originView.stringValue = code
        let candidateViews = getCandidateViews(candidates: candidates, origin: code)
        var width = getCandidatesWidth(candidateViews: candidateViews)
        if Fire.shared.cloudinput && code.count == 4 {
            topStackView.setViews([spinView], in: .center)
        } else {
            topStackView.setViews([], in: .center)
        }
        if let window = self.window as? FireCandidatesWindow {
            width = width > CGFloat(200) ? width : CGFloat(200)
            window.resizeRectFitContentView(NSRect(x: 0, y: 0, width: width, height: window.height))
        }
        candidatesView.setViews(candidateViews, in: .leading)
    }
    func updateNetCandidateView (candidate: Candidate?) {
        if candidate == nil {
            topStackView.setViews([], in: .center)
            return
        }
        let string = NSMutableAttributedString(string: "\(0).\(candidate!.text)", attributes: [
            NSAttributedString.Key.foregroundColor: NSColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 1),
            NSAttributedString.Key.font: NSFont.userFont(ofSize: 16)!
        ])
        let view = NSTextField(labelWithAttributedString: string)
        topStackView.setViews([view], in: .center)
    }

    private func getCandidatesWidth(candidateViews: [NSTextField]) -> CGFloat {
        let width = candidateViews.reduce(0) { (total: CGFloat, candidateView) -> CGFloat in
            return total + ceil(candidateView.attributedStringValue.size().width) + 12
        }
        return width
    }

}
