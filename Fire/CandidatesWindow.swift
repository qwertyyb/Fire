//
//  FireCandidatesWindow.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import SwiftUI
import InputMethodKit

typealias CandidatesData = (list: [Candidate], hasPrev: Bool, hasNext: Bool)

class CandidatesWindow: NSWindow, NSWindowDelegate {
    let hostingView = NSHostingView(rootView: CandidatesView(candidates: [], origin: ""))
    var inputController: FireInputController?

    func windowDidMove(_ notification: Notification) {
        /* windowDidMove会先于windowDidResize调用，所以需要
         * 在DispatchQueue.main.async中调用，以便能拿到最新的窗口大小
         **/
        DispatchQueue.main.async {
            self.limitFrameInScreen()
        }
    }

    func windowDidResize(_ notification: Notification) {
        /* 窗口大小变化时，确保不会超出当前屏幕范围，
         * 但是输入第一个字符时，也即窗口初次显示时，不会触发此事件, 所以需要配合windowDidMove方法一起使用
         */
        limitFrameInScreen()
    }

    func setCandidates(
        _ candidatesData: CandidatesData,
        originalString: String,
        topLeft: NSPoint
    ) {
        hostingView.rootView.candidates = candidatesData.list
        hostingView.rootView.origin = originalString
        hostingView.rootView.hasNext = candidatesData.hasNext
        hostingView.rootView.hasPrev = candidatesData.hasPrev
        NSLog("origin top left: \(topLeft)")
        NSLog("candidates: \(candidatesData)")
        self.setFrameTopLeftPoint(topLeft)
        self.orderFront(nil)
//        NSApp.setActivationPolicy(.prohibited)
    }
    
    func bindEvents() {
        let events: [NotificationObserver] = [
            (CandidatesView.candidateSelected, { notification in
                if let candidate = notification.userInfo?["candidate"] as? Candidate {
                    self.inputController?.insertCandidate(candidate)
                }
            }),
            (CandidatesView.prevPageBtnTapped, { _ in self.inputController?.prevPage() }),
            (CandidatesView.nextPageBtnTapped, { _ in self.inputController?.nextPage() }),
            (Fire.inputModeChanged, { notification in
                if notification.userInfo?["val"] as? InputMode == InputMode.enUS {
                    self.inputController?.insertOriginText()
                }
            })
        ]
        events.forEach { (observer) in NotificationCenter.default.addObserver(
          forName: observer.name, object: nil, queue: nil, using: observer.callback
        )}
        /**
        * 1.  由于使用recognizedEvents在一些场景下不能监听到flagChanged事件，比如保存文件场景
        *      所以这里需要使用NSEvent.addGlobalMonitorForEvents监听shift键被按下
        */
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            NSLog("[CandidatesWindow] globalMonitorForEvents flagsChanged: \(event)")
            if !InputSource.shared.isSelected() {
                return
            }
            _ = self.inputController?.flagChangedHandler(event: event)
        }
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        styleMask = .init(arrayLiteral: .fullSizeContentView, .borderless)
        isReleasedWhenClosed = false
        backgroundColor = NSColor.clear
        delegate = self
        setSizePolicy()
        bindEvents()
    }

    private func limitFrameInScreen() {
       let origin = self.transformTopLeft(originalTopLeft: NSPoint(x: self.frame.minX, y: self.frame.maxY))
       self.setFrameTopLeftPoint(origin)
    }

    private func setSizePolicy() {
        // 窗口大小可根据内容变化
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        guard self.contentView != nil else {
            return
        }
        self.contentView?.addSubview(hostingView)
        self.contentView?.leftAnchor.constraint(equalTo: hostingView.leftAnchor).isActive = true
        self.contentView?.rightAnchor.constraint(equalTo: hostingView.rightAnchor).isActive = true
        self.contentView?.topAnchor.constraint(equalTo: hostingView.topAnchor).isActive = true
        self.contentView?.bottomAnchor.constraint(equalTo: hostingView.bottomAnchor).isActive = true
    }

    private func transformTopLeft(originalTopLeft: NSPoint) -> NSPoint {
        NSLog("[FireCandidatesWindow] transformTopLeft: \(frame)")

        let screenPadding: CGFloat = 6

        var left = originalTopLeft.x
        var top = originalTopLeft.y
        if let curScreen = Utils.shared.getScreenFromPoint(originalTopLeft) {
            let screen = curScreen.frame

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
