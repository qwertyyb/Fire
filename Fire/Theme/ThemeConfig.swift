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

struct ColorData: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

extension Color {
    init(_ colorData: ColorData) {
        self.init(
            Color.RGBColorSpace.sRGBLinear,
            red: colorData.red,
            green: colorData.green,
            blue: colorData.blue,
            opacity: colorData.opacity
        )
    }
}

struct ApperanceThemeConfig: Codable {
    let windowBackgroundColor: ColorData
    let windowPaddingTop: Float
    let windowPaddingLeft: Float
    let windowPaddingRight: Float
    let windowPaddingBottom: Float
    let windowBorderRadius: Float

    let originCodeColor: ColorData
    let originCandidatesSpace: Float
    let candidateSpace: Float

    let candidateIndexColor: ColorData
    let candidateTextColor: ColorData
    let candidateCodeColor: ColorData

    let selectedIndexColor: ColorData
    let selectedTextColor: ColorData
    let selectedCodeColor: ColorData
    
    // 页面指示器颜色
    let pageIndicatorColor: ColorData
    // 页面指示器置灰色
    let pageIndicatorDisabledColor: ColorData

    let fontName: String
    let fontSize: Float
}

struct ThemeConfig: Codable {
    let id: String
    let name: String
    let author: String

    let light: ApperanceThemeConfig
    let dark: ApperanceThemeConfig?

    var current: ApperanceThemeConfig {
        light
    }

    subscript(colorScheme: ColorScheme) -> ApperanceThemeConfig {
        if let dark = self.dark, colorScheme == .dark {
            return dark
        }
        return light
    }
}

let defaultThemeConfig = ThemeConfig(
    id: "default",
    name: "默认",
    author: "业火输入法",
    light: ApperanceThemeConfig(
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
        pageIndicatorColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        pageIndicatorDisabledColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.4),
        fontName: "system",
        fontSize: 20),
    dark: ApperanceThemeConfig(
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
        pageIndicatorColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        pageIndicatorDisabledColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.4),
        fontName: "system",
        fontSize: 20
    )
)

func loadThemeConfig(jsonData: String) -> ThemeConfig? {
    let decoder = JSONDecoder()
    do {
        return try decoder.decode(ThemeConfig.self, from: jsonData.data(using: .utf8)!)
    } catch {
        print(error)
        return nil
    }
}

func jsonThemeConfig(config: ThemeConfig) -> String? {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(config) {
        return String(data: data, encoding: .utf8)!
    }
    return nil
}
