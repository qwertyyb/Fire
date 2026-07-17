//
//  ThemeConfig.swift
//  Fire
//
//  Created by 虚幻 on 2022/3/19.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI
import Defaults

struct ColorData: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.allSatisfy({ $0.isHexDigit }) else { return nil }

        let chars = Array(s)
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0, a: UInt64 = 255

        func parse(_ str: String) -> UInt64? {
            return UInt64(str, radix: 16)
        }

        switch chars.count {
        case 3:
            guard let pr = parse(String(repeating: chars[0], count: 2)),
                  let pg = parse(String(repeating: chars[1], count: 2)),
                  let pb = parse(String(repeating: chars[2], count: 2)) else { return nil }
            (r, g, b) = (pr, pg, pb)
        case 4:
            guard let pr = parse(String(repeating: chars[0], count: 2)),
                  let pg = parse(String(repeating: chars[1], count: 2)),
                  let pb = parse(String(repeating: chars[2], count: 2)),
                  let pa = parse(String(repeating: chars[3], count: 2)) else { return nil }
            (r, g, b, a) = (pr, pg, pb, pa)
        case 6:
            guard let pr = parse(String(chars[0...1])),
                  let pg = parse(String(chars[2...3])),
                  let pb = parse(String(chars[4...5])) else { return nil }
            (r, g, b) = (pr, pg, pb)
        case 8:
            guard let pr = parse(String(chars[0...1])),
                  let pg = parse(String(chars[2...3])),
                  let pb = parse(String(chars[4...5])),
                  let pa = parse(String(chars[6...7])) else { return nil }
            (r, g, b, a) = (pr, pg, pb, pa)
        default:
            return nil
        }

        self.red = Double(r) / 255.0
        self.green = Double(g) / 255.0
        self.blue = Double(b) / 255.0
        self.opacity = Double(a) / 255.0
    }

    var hexString: String {
        func toHex(_ value: Double) -> String {
            let clamped = max(0, min(1, value))
            return String(format: "%02X", Int((clamped * 255).rounded()))
        }
        let base = "#\(toHex(red))\(toHex(green))\(toHex(blue))"
        if opacity >= 1.0 - .ulpOfOne {
            return base
        }
        return "\(base)\(toHex(opacity))"
    }

    private enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let hex = try? single.decode(String.self),
           let parsed = ColorData(hex: hex) {
            self.init(
                red: parsed.red,
                green: parsed.green,
                blue: parsed.blue,
                opacity: parsed.opacity
            )
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let opacity = try container.decode(Double.self, forKey: .opacity)
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}

extension Color {
    init(_ colorData: ColorData) {
        self.init(
            Color.RGBColorSpace.sRGB,
            red: colorData.red,
            green: colorData.green,
            blue: colorData.blue,
            opacity: colorData.opacity
        )
    }
}

struct AppearanceThemeConfig: Codable, Equatable {
    var windowBackgroundColor: ColorData
    var windowPaddingTop: Float
    var windowPaddingLeft: Float
    var windowPaddingRight: Float
    var windowPaddingBottom: Float
    var windowBorderRadius: Float

    var originCodeColor: ColorData
    var originCandidatesSpace: Float
    var candidateSpace: Float

    var candidateIndexColor: ColorData
    var candidateTextColor: ColorData
    var candidateCodeColor: ColorData

    var selectedIndexColor: ColorData
    var selectedTextColor: ColorData
    var selectedCodeColor: ColorData

    // 页面指示器颜色
    var pageIndicatorColor: ColorData
    // 页面指示器置灰色
    var pageIndicatorDisabledColor: ColorData

    var fontName: String
    var fontSize: Float

    /** V2版本新增字段 **/
    // 原码上下左右内边距（0 = 紧贴内容）
    var originPaddingTop: Float
    var originPaddingLeft: Float
    var originPaddingRight: Float
    var originPaddingBottom: Float
    // 选中候选词的背景高亮色（透明 = 不高亮）
    var selectedBackgroundColor: ColorData
    // 候选项圆角
    var candidateRadius: Float
    // 候选项上下左右内边距（0 = 紧贴内容）
    var candidatePaddingTop: Float
    var candidatePaddingLeft: Float
    var candidatePaddingRight: Float
    var candidatePaddingBottom: Float
    // 候选序号独立字号（与正文 fontSize 解耦，可分别调节）
    var indexFontSize: Float
    // 编码提示独立字号
    var codeFontSize: Float
    // 毛玻璃效果开关（Liquid Glass 背景材质）
    var enableLiquidGlass: Bool

    enum CodingKeys: String, CodingKey {
        case windowBackgroundColor, windowPaddingTop, windowPaddingLeft, windowPaddingRight, windowPaddingBottom
        case windowBorderRadius
        case originCodeColor, originCandidatesSpace, candidateSpace
        case candidateIndexColor, candidateTextColor, candidateCodeColor
        case selectedIndexColor, selectedTextColor, selectedCodeColor
        case pageIndicatorColor, pageIndicatorDisabledColor
        case fontName, fontSize
        case originPaddingTop, originPaddingLeft, originPaddingRight, originPaddingBottom
        case selectedBackgroundColor
        case candidateRadius, candidatePaddingTop, candidatePaddingLeft, candidatePaddingRight, candidatePaddingBottom
        // 旧 key，仅用于 decode 兼容
        case selectedBackgroundRadius, selectedPaddingTop, selectedPaddingLeft, selectedPaddingRight, selectedPaddingBottom
        case indexFontSize, codeFontSize
        case enableLiquidGlass
    }

    init(
        windowBackgroundColor: ColorData,
        windowPaddingTop: Float,
        windowPaddingLeft: Float,
        windowPaddingRight: Float,
        windowPaddingBottom: Float,
        windowBorderRadius: Float,
        originCodeColor: ColorData,
        originCandidatesSpace: Float,
        candidateSpace: Float,
        candidateIndexColor: ColorData,
        candidateTextColor: ColorData,
        candidateCodeColor: ColorData,
        selectedIndexColor: ColorData,
        selectedTextColor: ColorData,
        selectedCodeColor: ColorData,
        pageIndicatorColor: ColorData,
        pageIndicatorDisabledColor: ColorData,
        fontName: String,
        fontSize: Float,
        indexFontSize: Float,
        codeFontSize: Float,
        enableLiquidGlass: Bool,
        originPaddingTop: Float = 0,
        originPaddingLeft: Float = 0,
        originPaddingRight: Float = 0,
        originPaddingBottom: Float = 0,
        selectedBackgroundColor: ColorData = ColorData(red: 0, green: 0, blue: 0, opacity: 0),
        candidateRadius: Float = 4,
        candidatePaddingTop: Float = 2,
        candidatePaddingLeft: Float = 2,
        candidatePaddingRight: Float = 2,
        candidatePaddingBottom: Float = 2
    ) {
        self.windowBackgroundColor = windowBackgroundColor
        self.windowPaddingTop = windowPaddingTop
        self.windowPaddingLeft = windowPaddingLeft
        self.windowPaddingRight = windowPaddingRight
        self.windowPaddingBottom = windowPaddingBottom
        self.windowBorderRadius = windowBorderRadius
        self.originCodeColor = originCodeColor
        self.originCandidatesSpace = originCandidatesSpace
        self.candidateSpace = candidateSpace
        self.candidateIndexColor = candidateIndexColor
        self.candidateTextColor = candidateTextColor
        self.candidateCodeColor = candidateCodeColor
        self.selectedIndexColor = selectedIndexColor
        self.selectedTextColor = selectedTextColor
        self.selectedCodeColor = selectedCodeColor
        self.pageIndicatorColor = pageIndicatorColor
        self.pageIndicatorDisabledColor = pageIndicatorDisabledColor
        self.fontName = fontName
        self.fontSize = fontSize
        self.originPaddingTop = originPaddingTop
        self.originPaddingLeft = originPaddingLeft
        self.originPaddingRight = originPaddingRight
        self.originPaddingBottom = originPaddingBottom
        self.selectedBackgroundColor = selectedBackgroundColor
        self.candidateRadius = candidateRadius
        self.candidatePaddingTop = candidatePaddingTop
        self.candidatePaddingLeft = candidatePaddingLeft
        self.candidatePaddingRight = candidatePaddingRight
        self.candidatePaddingBottom = candidatePaddingBottom
        self.indexFontSize = indexFontSize
        self.codeFontSize = codeFontSize
        self.enableLiquidGlass = enableLiquidGlass
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windowBackgroundColor = try container.decode(ColorData.self, forKey: .windowBackgroundColor)
        windowPaddingTop = try container.decode(Float.self, forKey: .windowPaddingTop)
        windowPaddingLeft = try container.decode(Float.self, forKey: .windowPaddingLeft)
        windowPaddingRight = try container.decode(Float.self, forKey: .windowPaddingRight)
        windowPaddingBottom = try container.decode(Float.self, forKey: .windowPaddingBottom)
        windowBorderRadius = try container.decode(Float.self, forKey: .windowBorderRadius)
        originCodeColor = try container.decode(ColorData.self, forKey: .originCodeColor)
        originCandidatesSpace = try container.decode(Float.self, forKey: .originCandidatesSpace)
        candidateSpace = try container.decode(Float.self, forKey: .candidateSpace)
        candidateIndexColor = try container.decode(ColorData.self, forKey: .candidateIndexColor)
        candidateTextColor = try container.decode(ColorData.self, forKey: .candidateTextColor)
        candidateCodeColor = try container.decode(ColorData.self, forKey: .candidateCodeColor)
        selectedIndexColor = try container.decode(ColorData.self, forKey: .selectedIndexColor)
        selectedTextColor = try container.decode(ColorData.self, forKey: .selectedTextColor)
        selectedCodeColor = try container.decode(ColorData.self, forKey: .selectedCodeColor)
        pageIndicatorColor = try container.decode(ColorData.self, forKey: .pageIndicatorColor)
        pageIndicatorDisabledColor = try container.decode(ColorData.self, forKey: .pageIndicatorDisabledColor)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(Float.self, forKey: .fontSize)
        originPaddingTop = try container.decodeIfPresent(Float.self, forKey: .originPaddingTop) ?? 0
        originPaddingLeft = try container.decodeIfPresent(Float.self, forKey: .originPaddingLeft) ?? 0
        originPaddingRight = try container.decodeIfPresent(Float.self, forKey: .originPaddingRight) ?? 0
        originPaddingBottom = try container.decodeIfPresent(Float.self, forKey: .originPaddingBottom) ?? 0
        selectedBackgroundColor = try container.decodeIfPresent(ColorData.self, forKey: .selectedBackgroundColor)
            ?? ColorData(red: 0, green: 0, blue: 0, opacity: 0)
        candidateRadius = try container.decodeIfPresent(Float.self, forKey: .candidateRadius)
            ?? (try container.decodeIfPresent(Float.self, forKey: .selectedBackgroundRadius)) ?? 4
        candidatePaddingTop = try container.decodeIfPresent(Float.self, forKey: .candidatePaddingTop)
            ?? (try container.decodeIfPresent(Float.self, forKey: .selectedPaddingTop)) ?? 2
        candidatePaddingLeft = try container.decodeIfPresent(Float.self, forKey: .candidatePaddingLeft)
            ?? (try container.decodeIfPresent(Float.self, forKey: .selectedPaddingLeft)) ?? 2
        candidatePaddingRight = try container.decodeIfPresent(Float.self, forKey: .candidatePaddingRight)
            ?? (try container.decodeIfPresent(Float.self, forKey: .selectedPaddingRight)) ?? 2
        candidatePaddingBottom = try container.decodeIfPresent(Float.self, forKey: .candidatePaddingBottom)
            ?? (try container.decodeIfPresent(Float.self, forKey: .selectedPaddingBottom)) ?? 2
        indexFontSize = try container.decode(Float.self, forKey: .indexFontSize)
        codeFontSize = try container.decode(Float.self, forKey: .codeFontSize)
        enableLiquidGlass = try container.decode(Bool.self, forKey: .enableLiquidGlass)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windowBackgroundColor, forKey: .windowBackgroundColor)
        try container.encode(windowPaddingTop, forKey: .windowPaddingTop)
        try container.encode(windowPaddingLeft, forKey: .windowPaddingLeft)
        try container.encode(windowPaddingRight, forKey: .windowPaddingRight)
        try container.encode(windowPaddingBottom, forKey: .windowPaddingBottom)
        try container.encode(windowBorderRadius, forKey: .windowBorderRadius)
        try container.encode(originCodeColor, forKey: .originCodeColor)
        try container.encode(originCandidatesSpace, forKey: .originCandidatesSpace)
        try container.encode(candidateSpace, forKey: .candidateSpace)
        try container.encode(candidateIndexColor, forKey: .candidateIndexColor)
        try container.encode(candidateTextColor, forKey: .candidateTextColor)
        try container.encode(candidateCodeColor, forKey: .candidateCodeColor)
        try container.encode(selectedIndexColor, forKey: .selectedIndexColor)
        try container.encode(selectedTextColor, forKey: .selectedTextColor)
        try container.encode(selectedCodeColor, forKey: .selectedCodeColor)
        try container.encode(pageIndicatorColor, forKey: .pageIndicatorColor)
        try container.encode(pageIndicatorDisabledColor, forKey: .pageIndicatorDisabledColor)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(originPaddingTop, forKey: .originPaddingTop)
        try container.encode(originPaddingLeft, forKey: .originPaddingLeft)
        try container.encode(originPaddingRight, forKey: .originPaddingRight)
        try container.encode(originPaddingBottom, forKey: .originPaddingBottom)
        try container.encode(selectedBackgroundColor, forKey: .selectedBackgroundColor)
        try container.encode(candidateRadius, forKey: .candidateRadius)
        try container.encode(candidatePaddingTop, forKey: .candidatePaddingTop)
        try container.encode(candidatePaddingLeft, forKey: .candidatePaddingLeft)
        try container.encode(candidatePaddingRight, forKey: .candidatePaddingRight)
        try container.encode(candidatePaddingBottom, forKey: .candidatePaddingBottom)
        try container.encode(indexFontSize, forKey: .indexFontSize)
        try container.encode(codeFontSize, forKey: .codeFontSize)
        try container.encode(enableLiquidGlass, forKey: .enableLiquidGlass)
    }
}

struct ThemeConfig: Codable, Defaults.Serializable {
    /** V2版本新增字段 **/
    let schemaVersion: Int?
    let id: String
    let name: String
    let author: String

    let light: AppearanceThemeConfig
    let dark: AppearanceThemeConfig?

    subscript(colorScheme: ColorScheme) -> AppearanceThemeConfig {
        if let dark = self.dark, colorScheme == .dark {
            return dark
        }
        return light
    }
}

let themeSchemaVersion = 2

let defaultThemeConfig = ThemeConfig(
    schemaVersion: themeSchemaVersion,
    id: "default",
    name: "默认",
    author: "业火输入法",
    light: AppearanceThemeConfig(
        windowBackgroundColor: ColorData(red: 1, green: 1, blue: 1, opacity: 1),
        windowPaddingTop: 0,
        windowPaddingLeft: 0,
        windowPaddingRight: 0,
        windowPaddingBottom: 0,
        windowBorderRadius: 6,
        originCodeColor: ColorData(red: 0.3, green: 0.3, blue: 0.3, opacity: 1),
        originCandidatesSpace: 0,
        candidateSpace: 0,
        candidateIndexColor: ColorData(red: 0.1, green: 0.1, blue: 0.1, opacity: 1),
        candidateTextColor: ColorData(red: 0.1, green: 0.1, blue: 0.1, opacity: 1),
        candidateCodeColor: ColorData(red: 0.3, green: 0.3, blue: 0.3, opacity: 0.8),
        selectedIndexColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedTextColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedCodeColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.8),
        pageIndicatorColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        pageIndicatorDisabledColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.4),
        fontName: "system",
        fontSize: 20,
        indexFontSize: 20,
        codeFontSize: 20,
        enableLiquidGlass: true,
        originPaddingTop: 6,
        originPaddingLeft: 8,
        originPaddingRight: 8,
        originPaddingBottom: 6,
        selectedBackgroundColor: ColorData(red: 0, green: 0, blue: 0, opacity: 0.06),
        candidateRadius: 0,
        candidatePaddingTop: 6,
        candidatePaddingLeft: 8,
        candidatePaddingRight: 8,
        candidatePaddingBottom: 6),
    dark: AppearanceThemeConfig(
        windowBackgroundColor: ColorData(red: 0, green: 0, blue: 0, opacity: 1),
        windowPaddingTop: 0,
        windowPaddingLeft: 0,
        windowPaddingRight: 0,
        windowPaddingBottom: 0,
        windowBorderRadius: 6,
        originCodeColor: ColorData(red: 1, green: 1, blue: 1, opacity: 1),
        originCandidatesSpace: 0,
        candidateSpace: 0,
        candidateIndexColor: ColorData(red: 0.9, green: 0.9, blue: 0.9, opacity: 1),
        candidateTextColor: ColorData(red: 0.9, green: 0.9, blue: 0.9, opacity: 1),
        candidateCodeColor: ColorData(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.8),
        selectedIndexColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedTextColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedCodeColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.8),
        pageIndicatorColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        pageIndicatorDisabledColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.4),
        fontName: "system",
        fontSize: 20,
        indexFontSize: 20,
        codeFontSize: 20,
        enableLiquidGlass: true,
        originPaddingTop: 6,
        originPaddingLeft: 8,
        originPaddingRight: 8,
        originPaddingBottom: 6,
        selectedBackgroundColor: ColorData(red: 1, green: 1, blue: 1, opacity: 0.08),
        candidateRadius: 0,
        candidatePaddingTop: 6,
        candidatePaddingLeft: 8,
        candidatePaddingRight: 8,
        candidatePaddingBottom: 6
    )
)

func loadThemeConfig(jsonData: String) -> ThemeConfig? {
    let decoder = JSONDecoder()
    do {
        guard let jsonData = jsonData.data(using: .utf8) else { return nil }
        return try decoder.decode(ThemeConfig.self, from: jsonData)
    } catch {
        print(error)
        return nil
    }
}

func jsonThemeConfig(config: ThemeConfig) -> String? {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(config) {
        return String(data: data, encoding: .utf8)
    }
    return nil
}

enum ThemeImportError: Error, LocalizedError {
    case invalidJSON
    case missingFields

    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "无效的主题 JSON"
        case .missingFields: return "主题缺少 ID、名称或作者"
        }
    }
}

/// 解析 JSON 字符串为 ThemeConfig 并做基础校验
func parseThemeConfig(jsonData: String) -> Result<ThemeConfig, ThemeImportError> {
    guard let config = loadThemeConfig(jsonData: jsonData) else {
        return .failure(.invalidJSON)
    }
    if config.id.isEmpty || config.name.isEmpty || config.author.isEmpty {
        return .failure(.missingFields)
    }
    return .success(config)
}

/// 写入导入的主题并立即应用为当前主题
func applyImportedTheme(_ config: ThemeConfig) {
    // 同时维护旧版单主题和新版数组
    Defaults[.importedThemeConfig] = config
    var list = Defaults[.importedThemeConfigs]
    if let idx = list.firstIndex(where: { $0.id == config.id }) {
        list[idx] = config
    } else {
        list.append(config)
    }
    Defaults[.importedThemeConfigs] = list
    Defaults[.themeConfig] = config
}
