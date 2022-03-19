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

struct ColorData: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

extension Color {
    init(_ colorData: ColorData) {
        self.init(Color.RGBColorSpace.sRGBLinear, red: colorData.red, green: colorData.green, blue: colorData.blue, opacity: colorData.opacity)
    }
}

struct ThemeConfig: Codable {
    let windowBackgroundColor: ColorData
    let windowPaddingTop: Double
    let windowPaddingLeft: Double
    let windowPaddingRight: Double
    let windowPaddingBottom: Double
    let windowBorderRadius: Double

    let originCodeColor: ColorData

    let candidateIndexColor: ColorData
    let candidateTextColor: ColorData
    let candidateCodeColor: ColorData

    let selectedIndexColor: ColorData
    let selectedTextColor: ColorData
    let selectedCodeColor: ColorData

    let fontName: String
    let fontSize: Double

    static let defaultConfig = ThemeConfig(
        windowBackgroundColor: ColorData(red: 1, green: 1, blue: 1, opacity: 1),
        windowPaddingTop: 6,
        windowPaddingLeft: 10,
        windowPaddingRight: 10,
        windowPaddingBottom: 6,
        windowBorderRadius: 6,
        originCodeColor: ColorData(red: 0.3, green: 0.3, blue: 0.3, opacity: 1),
        candidateIndexColor: ColorData(red: 0.1, green: 0.1, blue: 0.1, opacity: 1),
        candidateTextColor: ColorData(red: 0.1, green: 0.1, blue: 0.1, opacity: 1),
        candidateCodeColor: ColorData(red: 0.3, green: 0.3, blue: 0.3, opacity: 0.8),
        selectedIndexColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedTextColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 1),
        selectedCodeColor: ColorData(red: 0.863, green: 0.078, blue: 0.235, opacity: 0.8),
        fontName: "system",
        fontSize: 20)

    static var current: ThemeConfig {
        get {
            ThemeConfig.defaultConfig
        }
    }
}

func loadThemeConfig(jsonData: String) -> ThemeConfig {
    let decoder = JSONDecoder()
    let config = try! decoder.decode(ThemeConfig.self, from: jsonData.data(using: .utf8)!)
    return config
}

func jsonThemeConfig(config: ThemeConfig) -> String {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(config)
    return String(data: data, encoding: .utf8)!
}
