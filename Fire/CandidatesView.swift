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

        return HStack(alignment: .center, spacing: 2) {
            if indexVisible {
                Text("\(index + 1).")
                    .font(.system(size: CGFloat(effectiveConfig.indexFontSize)))
                    .foregroundStyle(Color(indexColor))
            }
            Text(candidate.label)
                .font(.system(size: CGFloat(effectiveConfig.fontSize)))
                .foregroundStyle(Color(textColor))
            if hintMode == .spelling,
               let spelling = candidate.spelling {
                Text(spelling)
                    .font(Font.custom(RadicalFontManager.fontName, size: 12))
                    .foregroundStyle(Color(codeColor))
            }
            if hintMode == .wubiCode {
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
    @State private var hoverOutTask: DispatchWorkItem?
    @Environment(\.colorScheme) var colorScheme

    private var effectiveConfig: AppearanceThemeConfig {
        previewConfig ?? (themeConfig.schemaVersion == themeSchemaVersion ? themeConfig[colorScheme] : defaultThemeConfig[colorScheme])
    }

    private var effectiveDirection: CandidatesDirection {
        previewDirection ?? direction
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
                onHover: onCandidateHover,
                config: effectiveConfig
            )
        }
        .onHover { hovering in
            // 鼠标离开候选列表时延迟复位，避免划过间隙时闪烁
            hoverOutTask?.cancel()
            if !hovering {
                let task = DispatchWorkItem { onCandidateHover?(0) }
                hoverOutTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
            }
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
                        _candidatesView
                        _indicator
                            .padding(.leading, CGFloat(effectiveConfig.candidatePaddingLeft))
                            .padding(.trailing, CGFloat(effectiveConfig.candidatePaddingRight))
                    }
                    .fixedSize()
                } else {
                    VStack(alignment: .leading, spacing: CGFloat(effectiveConfig.candidateSpace)) {
                        _candidatesView
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
