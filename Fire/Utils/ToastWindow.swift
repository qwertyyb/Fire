//
//  ToastWindow.swift
//  Fire
//
//  Created by marchyang on 2020/10/30.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import SwiftUI

class ToastWindow: NSWindow, ToastWindowProtocol {
    struct ToastView: View {
        var text: String
        // large 为大字模式(用于"中"/"英"切换提示)，false 为小字文本提示
        var large: Bool = true
        var body: some View {
            VStack {
                Text(text)
                    .font(.system(size: large ? 50 : 15))
                    .fontWeight(large ? .bold : .regular)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(
                minWidth: large ? 120 : 80,
                minHeight: large ? 120 : 36
            )
            .padding(large ? EdgeInsets() : EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            .background(Color.black.opacity(0.5))
            .clipped()
            .cornerRadius(large ? 20 : 8)
        }
    }

    struct ToastView_Previews: PreviewProvider {
        static var previews: some View {
            ToastView(text: "中")
        }
    }

    private var timer: Timer?

    private let hostingView = NSHostingView(rootView: ToastView(text: ""))
    override var acceptsFirstResponder: Bool {
       return false
    }

    private func initWindow() {
        isOpaque = false
        backgroundColor = NSColor.clear
        styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
    }
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        initWindow()
        contentView = hostingView
    }

    private func positionWindow() {
        guard let screen = Utils.shared.getScreenFromPoint(NSEvent.mouseLocation) else {
            return
        }
        let cx = (screen.frame.minX + screen.frame.maxX) / 2 - frame.width / 2
        let cy = (screen.frame.maxY - screen.frame.minY) / 5 + screen.frame.minY
        self.setFrameOrigin(NSPoint(x: cx, y: cy))
    }

    func show(_ text: String, position: NSPoint) {
        timer?.invalidate()
        // 复位为大字模式及固定尺寸，避免被 showToast 改动后影响"中"/"英"显示
        hostingView.rootView.large = true
        hostingView.rootView.text = text
        setContentSize(NSSize(width: 120, height: 120))
        positionWindow()
        orderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { (_) in
            self.close()
        })
    }

    // 以小字、内容自适应的方式显示一段文本提示，位置仍居中
    // onHide 在提示自动消失后回调，便于调用方释放窗口
    func showToast(_ text: String, onHide: (() -> Void)? = nil) {
        timer?.invalidate()
        hostingView.rootView.large = false
        hostingView.rootView.text = text
        hostingView.layoutSubtreeIfNeeded()
        setContentSize(hostingView.fittingSize)
        positionWindow()
        orderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { (_) in
            self.close()
            onHide?()
        })
    }
}
