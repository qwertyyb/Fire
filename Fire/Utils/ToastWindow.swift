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
        var systemImage: String?
        var useAppIcon: Bool = false
        // large 为大字模式(用于"中"/"英"切换提示)，false 为小字文本提示
        var large: Bool = true
        @Environment(\.colorScheme) var colorScheme

        static func loadAppIcon() -> NSImage {
            if let url = Bundle.main.url(forResource: "fire", withExtension: "pdf"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            return NSImage()
        }

        var body: some View {
            VStack {
                if large && useAppIcon {
                    Image(nsImage: Self.loadAppIcon())
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9))
                        .frame(width: 60, height: 60)
                } else if let systemImage = systemImage, large {
                    Image(systemName: systemImage)
                        .font(.system(size: 50))
                        .fontWeight(.bold)
                        .foregroundStyle(colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9))
                } else {
                    Text(text)
                        .font(.system(size: large ? 50 : 18))
                        // 小字提示字号从 15 调大为 18，提升可读性
                        .fontWeight(large ? .bold : .regular)
                        .foregroundStyle(colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(
                minWidth: large ? 120 : 80,
                minHeight: large ? 120 : 36
            )
            .padding(large ? EdgeInsets() : EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            .background(
                GlassEffectView(cornerRadius: large ? 20 : 8, blendingMode: .behindWindow)
            )
            .clipped()
            .cornerRadius(large ? 20 : 8)
        }
    }

#Preview {
    ToastWindow.ToastView(text: "中")
}

    private var timer: Timer?

    deinit {
        timer?.invalidate()
    }

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
        hostingView.rootView.useAppIcon = text == "中"
        hostingView.rootView.systemImage = text == "英" ? "a.circle" : nil
        setContentSize(NSSize(width: 120, height: 120))
        positionWindow()
        orderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { [weak self] (_) in
            self?.close()
        })
    }

    // 以小字、内容自适应的方式显示一段文本提示，位置仍居中
    // onHide 在提示自动消失后回调，便于调用方释放窗口
    func showToast(_ text: String, duration: TimeInterval = 1.5, onHide: (() -> Void)? = nil) {
        timer?.invalidate()
        hostingView.rootView.large = false
        hostingView.rootView.text = text
        hostingView.rootView.systemImage = nil
        hostingView.rootView.useAppIcon = false
        hostingView.layoutSubtreeIfNeeded()
        setContentSize(hostingView.fittingSize)
        positionWindow()
        orderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { [weak self] (_) in
            self?.close()
            onHide?()
        })
    }
}
