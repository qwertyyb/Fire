//
//  RadicalFontManager.swift
//  Fire
//
//  Created by qq420100523 on 2026/7/2.
//

import Foundation
import CoreText

/// 管理黑体字根字体注册，用于候选词窗中显示五笔拆字字根（如 〈氵工〉）
/// 字体来源：https://github.com/mrshiqiqi/rime-wubi
/// 在 init 时自动注册到当前进程，注册后可在 SwiftUI Text 中通过 Font.custom("黑体字根") 使用
class RadicalFontManager {
    static let shared = RadicalFontManager()

    private var fontAvailable = false

    private init() {
        registerFont()
    }

    private func registerFont() {
        guard let fontURL = Bundle.main.url(
            forResource: "黑体字根",
            withExtension: "ttf",
            subdirectory: "font"
        ) else {
            NSLog("[RadicalFontManager] Font file not found")
            return
        }
        let status = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        if status {
            fontAvailable = true
            NSLog("[RadicalFontManager] Font registered: 黑体字根")
        } else {
            fontAvailable = false
            NSLog("[RadicalFontManager] Font registration failed, font may already be registered")
        }
    }

    var isFontAvailable: Bool {
        fontAvailable
    }
}
