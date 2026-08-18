//
//  InputShortcutRecorder.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/15.
//

import AppKit
import Carbon
import SwiftUI

enum InputShortcutRecorderMode {
    case fullKey
    case digit
}

/// 本地事件监听，捕获用户按下的快捷键组合
final class InputShortcutRecordingSession {
    var onCompleteFullKey: ((InputShortcut) -> Void)?
    var onCompleteDigit: ((DigitInputShortcut) -> Void)?
    var onCancel: (() -> Void)?
    var onHint: ((String) -> Void)?

    private var monitor: Any?
    private let mode: InputShortcutRecorderMode
    private var timeoutTask: DispatchWorkItem?

    init(mode: InputShortcutRecorderMode) {
        self.mode = mode
    }

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handle(event)
            return nil
        }
        let task = DispatchWorkItem { [weak self] in
            self?.onHint?("录制超时，已取消")
            self?.cancel()
        }
        timeoutTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: task)
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    func cancel() {
        stop()
        onCancel?()
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .keyDown else { return }

        if event.keyCode == UInt16(kVK_Escape) {
            cancel()
            return
        }

        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch mode {
        case .fullKey:
            guard !InputShortcutFormatting.modifierKeyCodes.contains(event.keyCode) else { return }
            guard !mods.isEmpty else {
                onHint?("请同时按住至少一个修饰键")
                return
            }
            stop()
            onCompleteFullKey?(InputShortcut(keyCode: event.keyCode, modifiers: mods))

        case .digit:
            guard InputShortcut.digitByKeyCode[event.keyCode] != nil else {
                onHint?("请按下数字键 1–9 完成录制")
                return
            }
            guard !mods.isEmpty else {
                onHint?("请同时按住至少一个修饰键")
                return
            }
            stop()
            onCompleteDigit?(DigitInputShortcut(modifiers: mods))
        }
    }

    deinit {
        stop()
    }
}
