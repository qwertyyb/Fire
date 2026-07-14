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
    // 选中候选词的背景高亮色（透明 = 不高亮）
    var selectedBackgroundColor: ColorData
    // 选中候选词背景高亮圆角
    var selectedBackgroundRadius: Float
    // 选中高亮背景上下左右内边距（0 = 紧贴内容）
    var selectedPaddingTop: Float
    var selectedPaddingLeft: Float
    var selectedPaddingRight: Float
    var selectedPaddingBottom: Float

    // 页面指示器颜色
    var pageIndicatorColor: ColorData
    // 页面指示器置灰色
    var pageIndicatorDisabledColor: ColorData

    var fontName: String
    var fontSize: Float
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
        case selectedIndexColor, selectedTextColor, selectedCodeColor, selectedBackgroundColor, selectedBackgroundRadius
        case selectedPaddingTop, selectedPaddingLeft, selectedPaddingRight, selectedPaddingBottom
        case pageIndicatorColor, pageIndicatorDisabledColor
        case fontName, fontSize, indexFontSize, codeFontSize
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
        selectedBackgroundColor: ColorData = ColorData(red: 0, green: 0, blue: 0, opacity: 0),
        selectedBackgroundRadius: Float = 4,
        selectedPaddingTop: Float = 2,
        selectedPaddingLeft: Float = 2,
        selectedPaddingRight: Float = 2,
        selectedPaddingBottom: Float = 2,
        pageIndicatorColor: ColorData,
        pageIndicatorDisabledColor: ColorData,
        fontName: String,
        fontSize: Float,
        indexFontSize: Float,
        codeFontSize: Float,
        enableLiquidGlass: Bool
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
        self.selectedBackgroundColor = selectedBackgroundColor
        self.selectedBackgroundRadius = selectedBackgroundRadius
        self.selectedPaddingTop = selectedPaddingTop
        self.selectedPaddingLeft = selectedPaddingLeft
        self.selectedPaddingRight = selectedPaddingRight
        self.selectedPaddingBottom = selectedPaddingBottom
        self.pageIndicatorColor = pageIndicatorColor
        self.pageIndicatorDisabledColor = pageIndicatorDisabledColor
        self.fontName = fontName
        self.fontSize = fontSize
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
        selectedBackgroundColor = try container.decodeIfPresent(ColorData.self, forKey: .selectedBackgroundColor)
            ?? ColorData(red: 0, green: 0, blue: 0, opacity: 0)
        selectedBackgroundRadius = try container.decodeIfPresent(Float.self, forKey: .selectedBackgroundRadius) ?? 4
        selectedPaddingTop = try container.decodeIfPresent(Float.self, forKey: .selectedPaddingTop) ?? 2
        selectedPaddingLeft = try container.decodeIfPresent(Float.self, forKey: .selectedPaddingLeft) ?? 2
        selectedPaddingRight = try container.decodeIfPresent(Float.self, forKey: .selectedPaddingRight) ?? 2
        selectedPaddingBottom = try container.decodeIfPresent(Float.self, forKey: .selectedPaddingBottom) ?? 2
        pageIndicatorColor = try container.decode(ColorData.self, forKey: .pageIndicatorColor)
        pageIndicatorDisabledColor = try container.decode(ColorData.self, forKey: .pageIndicatorDisabledColor)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(Float.self, forKey: .fontSize)
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
        try container.encode(selectedBackgroundColor, forKey: .selectedBackgroundColor)
        try container.encode(selectedBackgroundRadius, forKey: .selectedBackgroundRadius)
        try container.encode(selectedPaddingTop, forKey: .selectedPaddingTop)
        try container.encode(selectedPaddingLeft, forKey: .selectedPaddingLeft)
        try container.encode(selectedPaddingRight, forKey: .selectedPaddingRight)
        try container.encode(selectedPaddingBottom, forKey: .selectedPaddingBottom)
        try container.encode(pageIndicatorColor, forKey: .pageIndicatorColor)
        try container.encode(pageIndicatorDisabledColor, forKey: .pageIndicatorDisabledColor)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(indexFontSize, forKey: .indexFontSize)
        try container.encode(codeFontSize, forKey: .codeFontSize)
        try container.encode(enableLiquidGlass, forKey: .enableLiquidGlass)
    }
}

struct ThemeConfig: Codable, Defaults.Serializable {
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

let schemaVersion = 2

let defaultThemeConfig = ThemeConfig(
    schemaVersion: schemaVersion,
    id: "default",
    name: "默认",
    author: "业火输入法",
    light: AppearanceThemeConfig(
        windowBackgroundColor: ColorData(red: 1, green: 1, blue: 1, opacity: 1),
        windowPaddingTop: 6,
        windowPaddingLeft: 10,
        windowPaddingRight: 10,
        windowPaddingBottom: 6,
        windowBorderRadius: 6,
        originCodeColor: ColorData(red: 0.3, green: 0.3, blue: 0.3, opacity: 1),
        originCandidatesSpace: 6,
        candidateSpace: 8,
        candidateIndexColor: ColorData(red: 0.1, green: 0.1, blue: 0.1, opacity: 1),
        candidateTextColor: ColorData(red: 0.1, green: 0.1, blue: 0.1, opacity: 1),
        candidateCodeColor: ColorData(red: 0.3, green: 0.3, blue: 0.3, opacity: 0.8),
        selectedIndexColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedTextColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedCodeColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.8),
        selectedBackgroundColor: ColorData(red: 0, green: 0, blue: 0, opacity: 0.06),
        selectedBackgroundRadius: 4,
        selectedPaddingTop: 4,
        selectedPaddingLeft: 8,
        selectedPaddingRight: 8,
        selectedPaddingBottom: 4,
        pageIndicatorColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        pageIndicatorDisabledColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.4),
        fontName: "system",
        fontSize: 20,
        indexFontSize: 20,
        codeFontSize: 20,
        enableLiquidGlass: true),
    dark: AppearanceThemeConfig(
        windowBackgroundColor: ColorData(red: 0, green: 0, blue: 0, opacity: 1),
        windowPaddingTop: 6,
        windowPaddingLeft: 10,
        windowPaddingRight: 10,
        windowPaddingBottom: 6,
        windowBorderRadius: 6,
        originCodeColor: ColorData(red: 1, green: 1, blue: 1, opacity: 1),
        originCandidatesSpace: 6,
        candidateSpace: 8,
        candidateIndexColor: ColorData(red: 0.9, green: 0.9, blue: 0.9, opacity: 1),
        candidateTextColor: ColorData(red: 0.9, green: 0.9, blue: 0.9, opacity: 1),
        candidateCodeColor: ColorData(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.8),
        selectedIndexColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedTextColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedCodeColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.8),
        selectedBackgroundColor: ColorData(red: 1, green: 1, blue: 1, opacity: 0.08),
        selectedBackgroundRadius: 4,
        selectedPaddingTop: 4,
        selectedPaddingLeft: 8,
        selectedPaddingRight: 8,
        selectedPaddingBottom: 4,
        pageIndicatorColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        pageIndicatorDisabledColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.4),
        fontName: "system",
        fontSize: 20,
        indexFontSize: 20,
        codeFontSize: 20,
        enableLiquidGlass: true
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
