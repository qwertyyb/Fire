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

class CandidatesWindow: NSPanel, NSWindowDelegate {
    let hostingView = NSHostingView(rootView: CandidatesView(candidates: [], origin: ""))
    var inputController: FireInputController?
    private var notificationObservers: [NSObjectProtocol] = []
    // 保存 globalMonitor 引用以便在 deinit 中移除，防止内存泄漏
    private var globalMonitor: Any?
    /// 刷新候选时忽略紧随的悬停事件，防止 SwiftUI 异步触发覆盖复位值
    private var refreshing = false

    /// 防止鼠标点击候选窗时切换焦点到正在输入的APP（NSPanel + nonactivatingPanel）
    override var canBecomeKey: Bool { false }
    /// 防止候选窗成为主窗口，避免输入法 App 被激活
    override var canBecomeMain: Bool { false }

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

    func setSelectedIndex(_ index: Int) {
        hostingView.rootView.selectedIndex = index
    }

    func setCandidates(
        _ candidatesData: CandidatesData,
        originalString: String,
        topLeft: NSPoint,
        selectedIndex: Int = 0
    ) {
        refreshing = true
        hostingView.rootView.candidates = candidatesData.list
        hostingView.rootView.origin = originalString
        hostingView.rootView.hasNext = candidatesData.hasNext
        hostingView.rootView.hasPrev = candidatesData.hasPrev
        hostingView.rootView.selectedIndex = selectedIndex
        hostingView.rootView.onCandidateHover = { [weak self] index in
            guard let self = self, !self.refreshing else { return }
            self.hostingView.rootView.selectedIndex = index
            self.inputController?.selectedIndex = index
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.refreshing = false
        }
        // 从 Fire.shared 获取当前激活的 inputController，确保鼠标点击选词时能找到
        if inputController == nil {
            inputController = Fire.shared.activeInputController
        }
        FireLog.input.debug("origin top left: \(String(describing: topLeft), privacy: .public)")
        FireLog.input.debug("candidates: \(String(describing: candidatesData))")
        self.setFrameTopLeftPoint(topLeft)
        self.orderFrontRegardless()
//        NSApp.setActivationPolicy(.prohibited)
    }

    func bindEvents() {
        let events: [NotificationObserver] = [
            (CandidatesView.candidateSelected, { [weak self] notification in
                if let candidate = notification.userInfo?["candidate"] as? Candidate {
                    self?.inputController?.insertCandidate(candidate, confirmed: true)
                }
            }),
            (CandidatesView.prevPageBtnTapped, { [weak self] _ in self?.inputController?.prevPage() }),
            (CandidatesView.nextPageBtnTapped, { [weak self] _ in self?.inputController?.nextPage() }),
            (Fire.inputModeChanged, { [weak self] notification in
                if notification.userInfo?["val"] as? InputMode == InputMode.enUS {
                    self?.inputController?.insertOriginText()
                }
            })
        ]
        // 保存 observer token 以便 deinit 时移除，防止通知回调悬挂导致崩溃
        events.forEach { (observer) in
            let token = NotificationCenter.default.addObserver(
                forName: observer.name, object: nil, queue: nil, using: observer.callback)
            notificationObservers.append(token)
        }
        // 由于使用IMKInputController recognizedEvents在一些场景下不能监听到flagChanged事件，比如保存文件和lanchPad场景
        // 所以这里需要使用NSEvent.addGlobalMonitorForEvents监听shift键被按下
        // 保存 globalMonitor 引用，用于 deinit 时移除
        // 全局 flagsChanged 监视器在后台线程回调，需派发到主线程再操作 UI
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] (event) in
            FireLog.input.debug("globalMonitorForEvents flagsChanged: \(String(describing: event), privacy: .public)")
            if !InputSource.shared.isSelected() {
                return
            }
            DispatchQueue.main.async {
                _ = self?.inputController?.flagChangedHandler(event: event)
            }
        }
    }

    deinit {
        // 移除所有通知监听器和全局事件监视器，防止对象释放后仍有回调被执行
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
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
        styleMask = .init(arrayLiteral: .fullSizeContentView, .borderless, .nonactivatingPanel)
        isReleasedWhenClosed = false
        backgroundColor = NSColor.clear
        isOpaque = false
        hidesOnDeactivate = false
        worksWhenModal = true
        // isOpaque = false 使窗口支持透明度，配合 Liquid Glass 毛玻璃效果
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
        hostingView.wantsLayer = true
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
        FireLog.input.debug("transformTopLeft: \(String(describing: self.frame), privacy: .public)")

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
