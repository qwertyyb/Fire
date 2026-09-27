//
//  FireCandidatesView.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
// 

import SwiftUI
import Defaults
import AppKit

// MARK: - 自定义毛玻璃背景（替代内置 .glassEffect()，实现圆角完全可控）

struct GlassEffectView: NSViewRepresentable {
    let cornerRadius: CGFloat
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.material = .popover
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
    }
}

// MARK: - 玻璃背景 ViewModifier（候选栏与预览浮窗共用）

extension View {
    @ViewBuilder
    func glassBackground(config: AppearanceThemeConfig) -> some View {
        self
            .background(
                Group {
                    if config.enableLiquidGlass {
                        ZStack {
                            Color(config.windowBackgroundColor)
                            GlassEffectView(cornerRadius: CGFloat(config.windowBorderRadius))
                        }
                    } else {
                        Color(config.windowBackgroundColor)
                    }
                }
            )
            .cornerRadius(CGFloat(config.windowBorderRadius))
    }
}

// MARK: - Liquid Glass Background
func getShownCode(candidate: Candidate, origin: String) -> String {
    if candidate.code.isEmpty {
        return ""
    }
    if candidate.type == CandidateType.py || !candidate.code.hasPrefix(origin) {
        return "(\(candidate.code))"
    }
    return candidate.code.count > origin.count
        ? "~\(String(candidate.code.suffix(candidate.code.count - origin.count)))"
        : ""
}

struct CandidateView: View {
    var candidate: Candidate
    var index: Int
    var origin: String
    var selected: Bool = false
    var indexVisible = true
    /// 竖向排列时占满可用宽度，使选中高亮铺满整行
    var fillWidth: Bool = false
    /// 非空时候选词按该宽度换行，避免候选窗超出屏幕
    var labelWidth: CGFloat? = nil
    var onHover: ((Int) -> Void)?
    /// 预览模式时传入，替代 @Default(.themeConfig) + @Environment
    var config: AppearanceThemeConfig?

    @Default(.themeConfig) private var themeConfig
    // 使用自定义候选提示模式，替代原有的 wubiCodeTip Bool 开关
    // 支持四种模式：none(不提示)、wubiCode(五笔码)、spelling(拆字)、pinyin(拼音)
    @Default(.candidateHintMode) private var hintMode
    @Environment(\.colorScheme) var colorScheme

    private var effectiveConfig: AppearanceThemeConfig {
        config ?? (themeConfig.schemaVersion == themeSchemaVersion ? themeConfig[colorScheme] : defaultThemeConfig[colorScheme])
    }

    var body: some View {
        let indexColor = selected
            ? effectiveConfig.selectedIndexColor
            : effectiveConfig.candidateIndexColor
        let textColor = selected
            ? effectiveConfig.selectedTextColor
            : effectiveConfig.candidateTextColor
        let codeColor = selected
            ? effectiveConfig.selectedCodeColor
            : effectiveConfig.candidateCodeColor

        return HStack(alignment: labelWidth == nil ? .center : .firstTextBaseline, spacing: 2) {
            if indexVisible {
                Text("\(index + 1).")
                    .font(.system(size: CGFloat(effectiveConfig.indexFontSize)))
                    .foregroundStyle(Color(indexColor))
            }
            Text(candidate.label)
                .font(.system(size: CGFloat(effectiveConfig.fontSize)))
                .foregroundStyle(Color(textColor))
                .multilineTextAlignment(.leading)
                .frame(width: labelWidth, alignment: .leading)
            if hintMode == .spelling,
               let spelling = candidate.spelling {
                Text(spelling)
                    .font(Font.custom(RadicalFontManager.fontName, size: 12))
                    .foregroundStyle(Color(codeColor))
            }
            if hintMode == .wubiCode && !getShownCode(candidate: candidate, origin: origin).isEmpty {
                Text(getShownCode(candidate: candidate, origin: origin))
                    .font(.system(size: CGFloat(effectiveConfig.codeFontSize)))
                    .foregroundStyle(Color(codeColor))
            }
            if hintMode == .pinyin,
               let pinyin = candidate.pinyin {
                Text("〔\(pinyin)〕")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(codeColor))
            }
        }
        .padding(.top, CGFloat(effectiveConfig.candidatePaddingTop))
        .padding(.bottom, CGFloat(effectiveConfig.candidatePaddingBottom))
        .padding(.leading, CGFloat(effectiveConfig.candidatePaddingLeft))
        .padding(.trailing, CGFloat(effectiveConfig.candidatePaddingRight))
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
        .background(
            Group {
                if selected {
                    RoundedRectangle(cornerRadius: CGFloat(effectiveConfig.candidateRadius))
                        .fill(Color(effectiveConfig.selectedBackgroundColor))
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            // 鼠标悬停时高亮跟随
            if hovering { onHover?(index) }
        }
        .onTapGesture {
            NotificationCenter.default.post(
                name: CandidatesView.candidateSelected,
                object: nil,
                userInfo: [
                    "candidate": candidate,
                    "index": index
                ]
            )
        }
    }
}

/// 横向排版中的一段。一个候选词可以拆成多段，接在上一行剩余宽度后面。
private struct CandidatePiece: Hashable {
    var index: Int
    var showIndex: Bool
    var label: String
    var hint: String
}

struct CandidatesView: View {
    static let candidateSelected = Notification.Name("CandidatesView.candidateSelected")
    static let nextPageBtnTapped = Notification.Name("CandidatesView.nextPageBtnTapped")
    static let prevPageBtnTapped = Notification.Name("CandidatesView.prevPageBtnTapped")

    var candidates: [Candidate]
    var origin: String
    var hasPrev: Bool = false
    var hasNext: Bool = false
    var selectedIndex: Int = 0
    /// 鼠标悬停候选词回调，由 CandidatesWindow 注入，同步更新视图和控制器的 selectedIndex
    var onCandidateHover: ((Int) -> Void)?
    /// 预览模式覆写：传入后替代 @Default(.themeConfig) + @Environment
    var previewConfig: AppearanceThemeConfig?
    /// 预览模式覆写排列方向
    var previewDirection: CandidatesDirection?

    @Default(.candidatesDirection) private var direction
    @Default(.themeConfig) private var themeConfig
    @Default(.showCodeInWindow) private var showCodeInWindow
    @Default(.candidateHintMode) private var hintMode
    @State private var hoverOutTask: DispatchWorkItem?
    @Environment(\.colorScheme) var colorScheme

    private var effectiveConfig: AppearanceThemeConfig {
        previewConfig ?? (themeConfig.schemaVersion == themeSchemaVersion ? themeConfig[colorScheme] : defaultThemeConfig[colorScheme])
    }

    private var effectiveDirection: CandidatesDirection {
        previewDirection ?? direction
    }

    /// 行宽随字号变化，约为屏幕宽度的四成出头，与鼠须管 maxTextWidth 同一公式。
    private var contentMaxWidth: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1280
        let fontScale = CGFloat(effectiveConfig.fontSize) / 12
        let ratio = min(1, 1.0 / 3.0 + fontScale / 12)
        let inset = CGFloat(effectiveConfig.windowPaddingLeft + effectiveConfig.windowPaddingRight)
        var width = screenWidth * ratio - inset
        if effectiveDirection == .horizontal {
            width -= horizontalIndicatorWidth
        }
        return max(CGFloat(effectiveConfig.fontSize) * 4, width)
    }

    private var horizontalIndicatorWidth: CGFloat {
        guard candidates.count > 1 || hasPrev || hasNext else { return 0 }
        return CGFloat(effectiveConfig.fontSize) * 0.5
            + CGFloat(effectiveConfig.candidatePaddingLeft + effectiveConfig.candidatePaddingRight)
            + CGFloat(effectiveConfig.candidateSpace)
    }

    private func measuredWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func hintWidth(for candidate: Candidate) -> CGFloat {
        switch hintMode {
        case .none:
            return 0
        case .spelling:
            guard let spelling = candidate.spelling, !spelling.isEmpty else { return 0 }
            let font = NSFont(name: RadicalFontManager.fontName, size: 12) ?? .systemFont(ofSize: 12)
            return measuredWidth(spelling, font: font)
        case .wubiCode:
            let code = getShownCode(candidate: candidate, origin: origin)
            guard !code.isEmpty else { return 0 }
            return measuredWidth(code, font: .systemFont(ofSize: CGFloat(effectiveConfig.codeFontSize)))
        case .pinyin:
            guard let pinyin = candidate.pinyin, !pinyin.isEmpty else { return 0 }
            return measuredWidth("〔\(pinyin)〕", font: .systemFont(ofSize: 12))
        }
    }

    /// 序号、提示和内边距之外，留给候选词本身的宽度。超出时返回换行宽度。
    private func labelWidth(index: Int, candidate: Candidate) -> CGFloat? {
        let font = NSFont.systemFont(ofSize: CGFloat(effectiveConfig.fontSize))
        let natural = measuredWidth(candidate.label, font: font)
        var chrome = CGFloat(effectiveConfig.candidatePaddingLeft + effectiveConfig.candidatePaddingRight)
        var parts = 1
        if candidates.count > 1 {
            chrome += measuredWidth("\(index + 1).", font: .systemFont(ofSize: CGFloat(effectiveConfig.indexFontSize)))
            parts += 1
        }
        let hint = hintWidth(for: candidate)
        if hint > 0 {
            chrome += hint
            parts += 1
        }
        chrome += CGFloat(parts - 1) * 2
        let limit = contentMaxWidth - chrome
        guard natural > limit else { return nil }
        return max(CGFloat(effectiveConfig.fontSize), limit)
    }

    private func hintText(for candidate: Candidate) -> String {
        switch hintMode {
        case .none:
            return ""
        case .spelling:
            return candidate.spelling ?? ""
        case .wubiCode:
            return getShownCode(candidate: candidate, origin: origin)
        case .pinyin:
            guard let pinyin = candidate.pinyin, !pinyin.isEmpty else { return "" }
            return "〔\(pinyin)〕"
        }
    }

    private func hintFont() -> NSFont {
        switch hintMode {
        case .spelling:
            return NSFont(name: RadicalFontManager.fontName, size: 12) ?? .systemFont(ofSize: 12)
        case .wubiCode:
            return .systemFont(ofSize: CGFloat(effectiveConfig.codeFontSize))
        case .pinyin, .none:
            return .systemFont(ofSize: 12)
        }
    }

    /// 一段候选（序号、正文切片、提示、左右内边距）的宽度，与 candidatePiece 的排版一致。
    private func pieceWidth(showIndex: Bool, index: Int, label: String, hint: String) -> CGFloat {
        var width = CGFloat(effectiveConfig.candidatePaddingLeft + effectiveConfig.candidatePaddingRight)
        var parts = 0
        if showIndex {
            width += measuredWidth("\(index + 1).", font: .systemFont(ofSize: CGFloat(effectiveConfig.indexFontSize)))
            parts += 1
        }
        if !label.isEmpty {
            width += measuredWidth(label, font: .systemFont(ofSize: CGFloat(effectiveConfig.fontSize)))
            parts += 1
        }
        if !hint.isEmpty {
            width += measuredWidth(hint, font: hintFont())
            parts += 1
        }
        if parts > 1 {
            width += 2 * CGFloat(parts - 1)
        }
        return width
    }

    /// 在 maxWidth 内容纳的最长正文前缀，不含提示。放不下一个字时返回空字符串。
    private func fittingLabelPrefix(_ text: String, index: Int, showIndex: Bool, maxWidth: CGFloat) -> String {
        let chars = Array(text)
        guard !chars.isEmpty else { return "" }
        var low = 1
        var high = chars.count
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            let slice = String(chars.prefix(mid))
            if pieceWidth(showIndex: showIndex, index: index, label: slice, hint: "") <= maxWidth {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return String(chars.prefix(best))
    }

    /// 横向候选按行宽流动：这一行还有空位就继续放下一个，放不下的部分再折行。
    private var horizontalLines: [[CandidatePiece]] {
        var lines: [[CandidatePiece]] = []
        var current: [CandidatePiece] = []
        var used: CGFloat = 0
        let limit = contentMaxWidth
        let gap = CGFloat(effectiveConfig.candidateSpace)
        let showIndex = candidates.count > 1

        func append(_ piece: CandidatePiece) {
            let spacing = current.isEmpty ? 0 : gap
            used += spacing + pieceWidth(showIndex: piece.showIndex, index: piece.index, label: piece.label, hint: piece.hint)
            current.append(piece)
        }

        func flush() {
            if !current.isEmpty {
                lines.append(current)
                current = []
                used = 0
            }
        }

        for (index, candidate) in candidates.enumerated() {
            var rest = candidate.label
            let hint = hintText(for: candidate)
            var first = true
            while true {
                if rest.isEmpty {
                    if !hint.isEmpty {
                        let spacing = current.isEmpty ? 0 : gap
                        let available = limit - used - spacing
                        if pieceWidth(showIndex: false, index: index, label: "", hint: hint) > available && !current.isEmpty {
                            flush()
                        }
                        append(CandidatePiece(index: index, showIndex: false, label: "", hint: hint))
                    } else if first {
                        append(CandidatePiece(index: index, showIndex: showIndex, label: "", hint: ""))
                    }
                    break
                }
                let spacing = current.isEmpty ? 0 : gap
                let available = limit - used - spacing
                let pieceShowsIndex = first && showIndex
                // 剩下的正文和提示都能放进当前行，这个候选词到此结束。
                if pieceWidth(showIndex: pieceShowsIndex, index: index, label: rest, hint: hint) <= available {
                    append(CandidatePiece(index: index, showIndex: pieceShowsIndex, label: rest, hint: hint))
                    break
                }
                // 连一个字都放不下，当前行只剩边角，换到下一行再排这个词。
                if !current.isEmpty && pieceWidth(showIndex: pieceShowsIndex, index: index, label: String(rest.prefix(1)), hint: "") > available {
                    flush()
                    continue
                }
                // 当前行还能放下一部分：留下最长前缀，其余正文从下一行继续，提示跟在最后一段后面。
                let slice = fittingLabelPrefix(rest, index: index, showIndex: pieceShowsIndex, maxWidth: available)
                let piece = slice.isEmpty ? String(rest.prefix(1)) : slice
                append(CandidatePiece(index: index, showIndex: pieceShowsIndex, label: piece, hint: ""))
                rest = String(rest.dropFirst(piece.count))
                first = false
                flush()
            }
        }
        flush()
        return lines
    }

    var _candidatesView: some View {
        // 使用 Candidate 的 Hashable 实现作为 id，
        // 避免候选词列表变化时不必要的视图重建（原 \.offset 在增删时会导致整个列表重绘）
        ForEach(Array(candidates.enumerated()), id: \.element) { (index, candidate) in
            CandidateView(
                candidate: candidate,
                index: index,
                origin: origin,
                selected: index == selectedIndex,
                indexVisible: candidates.count > 1,
                fillWidth: effectiveDirection == .vertical,
                labelWidth: labelWidth(index: index, candidate: candidate),
                onHover: onCandidateHover,
                config: effectiveConfig
            )
        }
    }

    private func resetHoverOnLeave(_ hovering: Bool) {
        // 鼠标离开候选列表时延迟复位，避免划过间隙时闪烁
        hoverOutTask?.cancel()
        if !hovering {
            let task = DispatchWorkItem { onCandidateHover?(0) }
            hoverOutTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
        }
    }

    private func candidatePiece(_ piece: CandidatePiece) -> some View {
        let selected = piece.index == selectedIndex
        let indexColor = selected ? effectiveConfig.selectedIndexColor : effectiveConfig.candidateIndexColor
        let textColor = selected ? effectiveConfig.selectedTextColor : effectiveConfig.candidateTextColor
        let codeColor = selected ? effectiveConfig.selectedCodeColor : effectiveConfig.candidateCodeColor
        let candidate = candidates[piece.index]
        return HStack(alignment: .center, spacing: 2) {
            if piece.showIndex {
                Text("\(piece.index + 1).")
                    .font(.system(size: CGFloat(effectiveConfig.indexFontSize)))
                    .foregroundStyle(Color(indexColor))
            }
            if !piece.label.isEmpty {
                Text(piece.label)
                    .font(.system(size: CGFloat(effectiveConfig.fontSize)))
                    .foregroundStyle(Color(textColor))
            }
            if !piece.hint.isEmpty {
                Text(piece.hint)
                    .font(hintMode == .spelling
                          ? Font.custom(RadicalFontManager.fontName, size: 12)
                          : .system(size: hintMode == .wubiCode ? CGFloat(effectiveConfig.codeFontSize) : 12))
                    .foregroundStyle(Color(codeColor))
            }
        }
        .padding(.top, CGFloat(effectiveConfig.candidatePaddingTop))
        .padding(.bottom, CGFloat(effectiveConfig.candidatePaddingBottom))
        .padding(.leading, CGFloat(effectiveConfig.candidatePaddingLeft))
        .padding(.trailing, CGFloat(effectiveConfig.candidatePaddingRight))
        .background(
            Group {
                if selected {
                    RoundedRectangle(cornerRadius: CGFloat(effectiveConfig.candidateRadius))
                        .fill(Color(effectiveConfig.selectedBackgroundColor))
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { onCandidateHover?(piece.index) }
        }
        .onTapGesture {
            NotificationCenter.default.post(
                name: CandidatesView.candidateSelected,
                object: nil,
                userInfo: [
                    "candidate": candidate,
                    "index": piece.index
                ]
            )
        }
    }

    func getIndicatorIcon(
        imageName: String,
        direction: CandidatesDirection,
        disabled: Bool,
        eventName: Notification.Name
    ) -> some View {
        let size = CGFloat(effectiveConfig.fontSize) * 0.5
        return Image(imageName)
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size, alignment: .center)
            .rotationEffect(Angle(degrees: direction == CandidatesDirection.horizontal ? 0 : -90), anchor: .center)
            .onTapGesture {
                if disabled { return }
                NotificationCenter.default.post(
                    name: eventName,
                    object: nil
                )
            }
            .foregroundStyle(Color(disabled
                                   ? effectiveConfig.pageIndicatorDisabledColor
                                   : effectiveConfig.pageIndicatorColor
                                  ))
    }

    @ViewBuilder
    var _indicator: some View {
        if candidates.count > 1 || hasPrev || hasNext {
            Group {
                if effectiveDirection == CandidatesDirection.horizontal {
                    VStack(spacing: 0) {
                        getIndicatorIcon(imageName: "arrowUp", direction: direction, disabled: !hasPrev, eventName: CandidatesView.prevPageBtnTapped)
                        getIndicatorIcon(imageName: "arrowDown", direction: direction, disabled: !hasNext, eventName: CandidatesView.nextPageBtnTapped)
                    }
                } else {
                    HStack(spacing: 4) {
                        getIndicatorIcon(imageName: "arrowUp", direction: effectiveDirection, disabled: !hasPrev, eventName: CandidatesView.prevPageBtnTapped)
                        getIndicatorIcon(imageName: "arrowDown", direction: effectiveDirection, disabled: !hasNext, eventName: CandidatesView.nextPageBtnTapped)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(effectiveConfig.originCandidatesSpace), content: {
            if showCodeInWindow {
                Text(origin)
                    .foregroundStyle(Color(effectiveConfig.originCodeColor))
                    .padding(.top, CGFloat(effectiveConfig.originPaddingTop))
                    .padding(.bottom, CGFloat(effectiveConfig.originPaddingBottom))
                    .padding(.leading, CGFloat(effectiveConfig.originPaddingLeft))
                    .padding(.trailing, CGFloat(effectiveConfig.originPaddingRight))
                    .fixedSize()
            }
            Group {
                if effectiveDirection == CandidatesDirection.horizontal {
                    HStack(alignment: .center, spacing: CGFloat(effectiveConfig.candidateSpace)) {
                        VStack(alignment: .leading, spacing: CGFloat(effectiveConfig.candidateSpace)) {
                            ForEach(Array(horizontalLines.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .center, spacing: CGFloat(effectiveConfig.candidateSpace)) {
                                    ForEach(Array(line.enumerated()), id: \.offset) { _, piece in
                                        candidatePiece(piece)
                                    }
                                }
                            }
                        }
                        .onHover(perform: resetHoverOnLeave)
                        _indicator
                            .padding(.leading, CGFloat(effectiveConfig.candidatePaddingLeft))
                            .padding(.trailing, CGFloat(effectiveConfig.candidatePaddingRight))
                    }
                    .fixedSize()
                } else {
                    VStack(alignment: .leading, spacing: CGFloat(effectiveConfig.candidateSpace)) {
                        _candidatesView
                            .onHover(perform: resetHoverOnLeave)
                        _indicator
                            .padding(.top, CGFloat(effectiveConfig.candidatePaddingTop))
                            .padding(.bottom, CGFloat(effectiveConfig.candidatePaddingBottom))
                            .padding(.leading, CGFloat(effectiveConfig.candidatePaddingLeft))
                    }
                }
            }
            .id(effectiveDirection)
        })
            .padding(.top, CGFloat(effectiveConfig.windowPaddingTop))
            .padding(.bottom, CGFloat(effectiveConfig.windowPaddingBottom))
            .padding(.leading, CGFloat(effectiveConfig.windowPaddingLeft))
            .padding(.trailing, CGFloat(effectiveConfig.windowPaddingRight))
            .fixedSize()
            .font(.system(size: CGFloat(effectiveConfig.fontSize)))
            .glassBackground(config: effectiveConfig)
    }
}

#Preview {
    CandidatesView(candidates: [
        Candidate(code: "a", text: "工", type: CandidateType.wb),
        Candidate(code: "ab", text: "戈", type: CandidateType.wb),
        Candidate(code: "abc", text: "啊", type: CandidateType.wb),
        Candidate(code: "abcg", text: "阿", type: CandidateType.wb),
        Candidate(code: "addd", text: "吖", type: CandidateType.wb)
    ], origin: "a")
}
