//
//  checkShiftUp.swift
//  Fire
//
//  Created by 虚幻 on 2020/8/15.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Defaults
import InputMethodKit
import SwiftUI

class Utils {
    // 以下四个正则提为 static let，避免 shouldConcatWithWhitespace 在每次按键时重复编译正则表达式
    // enDigitSuffix: 判断上次输入以英文或数字结尾
    private static let enDigitSuffix = try! NSRegularExpression(pattern: "[a-zA-Z0-9]$")
    // cnPrefix: 判断本次输入以中文开头
    private static let cnPrefix = try! NSRegularExpression(pattern: "^[\\u4e00-\\u9fa5]")
    // cnSuffix: 判断上次输入以中文结尾
    private static let cnSuffix = try! NSRegularExpression(pattern: "[\\u4e00-\\u9fa5]$")
    // enDigitPrefix: 判断本次输入以英文或数字开头
    private static let enDigitPrefix = try! NSRegularExpression(pattern: "^[a-zA-Z0-9]")

    var toast: ToastWindowProtocol?

    // 用于删除/组词等操作的小字文本提示，独立于中英文切换提示，不受 inputModeTipWindowType 影响
    // 低频操作，按需创建、隐藏后释放
    private var messageToast: ToastWindow?

    // 显示一段小字文本提示(居中)，提示消失后释放窗口
    func showMessage(_ text: String) {
        if messageToast == nil {
            messageToast = ToastWindow()
        }
        messageToast?.showToast(text, duration: 3.0) { [weak self] in
            self?.messageToast = nil
        }
    }

    private func initToastWindow() {
        toast = Defaults[.inputModeTipWindowType] == .centerScreen
            ? ToastWindow()
           : Defaults[.inputModeTipWindowType] == .followInput
               ? TipsWindow()
               : nil
    }
    init() {
        Defaults.observe(keys: .inputModeTipWindowType, .candidateCount) { () in
            self.initToastWindow()
        }.tieToLifetime(of: self)
    }
    func processHandlers<T>(
        handlers: [(NSEvent) -> T?]
    ) -> ((NSEvent) -> T?) {
        func handleFn(event: NSEvent) -> T? {
            for handler in handlers {
                if let result = handler(event) {
                    return result
                }
            }
            return nil
        }
        return handleFn
    }

    func getScreenFromPoint(_ point: NSPoint) -> NSScreen? {
        // find current screen
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }
    
    // 根据上次输入的字符，判断插入的新字符是否要前加空格
    func shouldConcatWithWhitespace(_ lastText: String, _ nextText: String) -> Bool {
        FireLog.utils.debug("shouldConcatWithWhitespace, lastText: \(lastText), nextText: \(nextText)")
        if lastText.isEmpty || nextText.isEmpty {
            return false
        }
        let firstEnReg = Utils.enDigitSuffix
        let nextCnReg = Utils.cnPrefix
        if firstEnReg.numberOfMatches(in: lastText, range: NSRange(location: 0, length: lastText.utf16.count)) > 0
            && nextCnReg.numberOfMatches(in: nextText, range: NSRange(location: 0, length: nextText.utf16.count)) > 0 {
            return true
        }
        let firstCnReg = Utils.cnSuffix
        let nextEnReg = Utils.enDigitPrefix
        return firstCnReg.numberOfMatches(in: lastText, range: NSRange(location: 0, length: lastText.utf16.count)) > 0
            && nextEnReg.numberOfMatches(in: nextText, range: NSRange(location: 0, length: nextText.utf16.count)) > 0
    }

    static let shared = Utils()
}

// MARK: - SQLite 公共辅助函数

/// 安全读取可为 NULL 的 SQLite 文本列
/// 当列值为 NULL 时返回 nil，避免 String(cString:) 传入 NULL 指针崩溃
func optString(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
    return String(cString: cStr)
}

/// 安全获取 SQLite 错误信息，database 为 nil 时返回 "nil"
func dbErrMsg(_ db: OpaquePointer?) -> String {
    guard let db = db, let cStr = sqlite3_errmsg(db) else { return "nil" }
    return String(cString: cStr)
}

/// 准备 SQL 语句，失败时返回 nil
func sqlitePrepare(_ db: OpaquePointer?, _ sql: String) -> OpaquePointer? {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    return stmt
}

/// 执行 SQL 查询，每行回调，自动 finalize
/// - Parameters:
///   - bind: 可选参数绑定闭包，在 prepare 后调用
///   - row: 每行回调，step 返回 SQLITE_ROW 时调用
func sqliteQuery(_ db: OpaquePointer?, _ sql: String,
                 bind: ((OpaquePointer) -> Void)? = nil,
                 row: (OpaquePointer) -> Void) {
    guard let stmt = sqlitePrepare(db, sql) else {
        FireLog.utils.error("SQLite prepare failed: \(sql) — \(dbErrMsg(db), privacy: .public)")
        return
    }
    defer { sqlite3_finalize(stmt) }
    bind?(stmt)
    while sqlite3_step(stmt) == SQLITE_ROW {
        row(stmt)
    }
}

// MARK: - NSApplication 扩展

extension NSApplication {
    /// 激活为 accessory 模式并置前，用于菜单栏触发的模态窗口（关于、更新、字根表）
    /// 若偏好设置窗口正在显示则跳过切换，保持 Dock 图标可见
    func activateAsAccessory() {
        if !FirePreferencesController.shared.isVisible {
            setActivationPolicy(.accessory)
        }
        activate(ignoringOtherApps: true)
    }
}
