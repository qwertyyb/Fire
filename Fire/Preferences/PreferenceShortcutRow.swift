//
//  PreferenceShortcutRow.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/15.
//

import SwiftUI

enum ShortcutRowRole {
    case quickCombine
    case pinCandidate
    case deleteCandidate
}

struct PreferenceShortcutRow: View {
    let title: String
    var caption: String? = nil
    let role: ShortcutRowRole
    let mode: InputShortcutRecorderMode
    @Binding var quickCombineShortcut: InputShortcut?
    @Binding var pinCandidateShortcut: DigitInputShortcut?
    @Binding var deleteCandidateShortcut: DigitInputShortcut?

    @State private var isRecording = false
    @State private var hintMessage: String?
    @State private var recordingSession: InputShortcutRecordingSession?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let hintMessage {
                    Text(hintMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            shortcutRecorderField
            Button("恢复默认") {
                restoreDefault()
            }
        }
        .padding(.vertical, 2)
        .onDisappear {
            stopRecording()
        }
    }

    private var hasShortcut: Bool {
        switch role {
        case .quickCombine: quickCombineShortcut != nil
        case .pinCandidate: pinCandidateShortcut != nil
        case .deleteCandidate: deleteCandidateShortcut != nil
        }
    }

    private var shortcutRecorderField: some View {
        HStack(spacing: 4) {
            Button {
                toggleRecording()
            } label: {
                Group {
                    if isRecording {
                        Text("按下快捷键…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        shortcutDisplay
                    }
                }
            }
            .buttonStyle(.plain)
            .help(isRecording ? "按 Esc 取消录制" : "点击录制快捷键")

            if hasShortcut && !isRecording {
                Button {
                    clearShortcut()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("清除快捷键")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .fixedSize(horizontal: true, vertical: false)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isRecording ? 1.5 : 1)
        }
    }

    @ViewBuilder
    private var shortcutDisplay: some View {
        switch mode {
        case .fullKey:
            if let shortcut = quickCombineShortcut {
                InputShortcutDisplay(
                    modifiers: shortcut.modifierFlags,
                    keyCode: shortcut.keyCode
                )
            } else {
                Text("未设置")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        case .digit:
            let shortcut = role == .pinCandidate ? pinCandidateShortcut : deleteCandidateShortcut
            if let shortcut {
                InputShortcutDisplay(
                    modifiers: shortcut.modifierFlags,
                    includeDigitPlaceholder: true
                )
            } else {
                Text("未设置")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
            return
        }
        hintMessage = nil
        isRecording = true
        let session = InputShortcutRecordingSession(mode: mode)
        session.onHint = { hintMessage = $0 }
        session.onCancel = {
            isRecording = false
            recordingSession = nil
        }
        session.onCompleteFullKey = { shortcut in
            applyFullKey(shortcut)
            isRecording = false
            recordingSession = nil
        }
        session.onCompleteDigit = { shortcut in
            applyDigit(shortcut)
            isRecording = false
            recordingSession = nil
        }
        recordingSession = session
        session.start()
    }

    private func stopRecording() {
        recordingSession?.cancel()
        recordingSession = nil
        isRecording = false
    }

    private func applyFullKey(_ shortcut: InputShortcut) {
        if let conflict = InputShortcutFormatting.conflicts(
            quickCombine: shortcut,
            pinCandidate: pinCandidateShortcut,
            deleteCandidate: deleteCandidateShortcut
        ) {
            hintMessage = conflict
            return
        }
        hintMessage = nil
        quickCombineShortcut = shortcut
    }

    private func applyDigit(_ shortcut: DigitInputShortcut) {
        var pin = pinCandidateShortcut
        var delete = deleteCandidateShortcut
        if role == .pinCandidate {
            pin = shortcut
        } else {
            delete = shortcut
        }
        if let conflict = InputShortcutFormatting.conflicts(
            quickCombine: quickCombineShortcut,
            pinCandidate: pin,
            deleteCandidate: delete
        ) {
            hintMessage = conflict
            return
        }
        hintMessage = nil
        if role == .pinCandidate {
            pinCandidateShortcut = shortcut
        } else {
            deleteCandidateShortcut = shortcut
        }
    }

    private func clearShortcut() {
        stopRecording()
        hintMessage = nil
        switch role {
        case .quickCombine:
            quickCombineShortcut = nil
        case .pinCandidate:
            pinCandidateShortcut = nil
        case .deleteCandidate:
            deleteCandidateShortcut = nil
        }
    }

    private func restoreDefault() {
        hintMessage = nil
        switch role {
        case .quickCombine:
            quickCombineShortcut = .defaultQuickCombine
        case .pinCandidate:
            pinCandidateShortcut = .defaultPinCandidate
        case .deleteCandidate:
            deleteCandidateShortcut = .defaultDeleteCandidate
        }
    }
}
