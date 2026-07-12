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
/// 在 init 时自动注册到当前进程，注册后可在 SwiftUI Text 中通过 Font.custom(fontName) 使用
class RadicalFontManager {
    static let shared = RadicalFontManager()
    static let fontName = "黑体字根"

    private var fontAvailable = false

    private init() {
        registerFont()
    }

    private func registerFont() {
        // Xcode 将 ttf 复制到 Resources 根目录，而非保留源码中的 font/ 子目录
        let fontURL = Bundle.main.url(forResource: Self.fontName, withExtension: "ttf")
            ?? Bundle.main.url(forResource: Self.fontName, withExtension: "ttf", subdirectory: "font")
        guard let fontURL else {
            NSLog("[RadicalFontManager] Font file not found in bundle")
            return
        }

        let registered = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        if registered {
            fontAvailable = true
            NSLog("[RadicalFontManager] Font registered: \(Self.fontName)")
            return
        }

        // 进程内重复注册会失败，确认字体是否已可用
        let font = CTFontCreateWithName(Self.fontName as CFString, 12, nil)
        fontAvailable = (CTFontCopyFamilyName(font) as String) == Self.fontName
        if fontAvailable {
            NSLog("[RadicalFontManager] Font already available: \(Self.fontName)")
        } else {
            NSLog("[RadicalFontManager] Font registration failed")
        }
    }

    var isFontAvailable: Bool {
        fontAvailable
    }
}
