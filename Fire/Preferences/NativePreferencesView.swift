//
//  NativePreferencesView.swift
//  Fire
//
//  Created by 业火五笔 on 2026/7/5.
//  Copyright © 2026 qwertyyb. All rights reserved.
//

import SwiftUI

/// 系统设置风格的偏好设置窗口：NavigationSplitView 侧栏 + 详情
///
/// 核心设计：
/// - 侧栏：List(selection:) + .listStyle(.sidebar) 原生 Liquid Glass 侧栏
///   - 分 4 个 Section 分组（编码与输入、符号与词库、应用与外观、数据与系统）
///   - 每项带彩色渐变圆角徽章图标（24×24pt，cornerRadius:6）
///   - 收缩按钮在侧栏 toolbar 中
/// - 详情：根据 localSelection 切换对应的设置面板
/// - 状态同步：localSelection ←→ controller.selectedPane 通过 onChange + onReceive 双向同步
struct NativePreferencesView: View {
    /// 侧栏选中项及详情视图的唯一数据源
    @State private var localSelection: String = "基本"
    /// 通过 EnvironmentObject 接收外部 showPane() 导航
    @EnvironmentObject private var controller: FirePreferencesController

    private struct PaneItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let tint: Color
    }

    private let panes: [PaneItem] = [
        PaneItem(id: "基本", icon: "gearshape", title: "基本", tint: .gray),
        PaneItem(id: "标点符号", icon: "text.quote", title: "标点符号", tint: .teal),
        PaneItem(id: "用户词库", icon: "book", title: "用户词库", tint: .blue),
        PaneItem(id: "应用", icon: "app.badge", title: "应用", tint: .indigo),
        PaneItem(id: "主题", icon: "paintpalette", title: "主题", tint: .purple),
        PaneItem(id: "统计", icon: "chart.bar", title: "统计", tint: .orange),
        PaneItem(id: "高级", icon: "gearshape.2", title: "高级", tint: .brown),
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $localSelection) {
                Section("编码与输入") {
                    row(for: panes[0])
                }
                Section("符号与词库") {
                    row(for: panes[1])
                    row(for: panes[2])
                }
                Section("应用与外观") {
                    row(for: panes[3])
                    row(for: panes[4])
                }
                Section("数据与系统") {
                    row(for: panes[5])
                    row(for: panes[6])
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
            .toolbar {
                ToolbarItemGroup {
                    Spacer()
                    Button {
                        NSApp.keyWindow?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .help("切换侧栏")
                }
            }
        } detail: {
            detail(for: localSelection)
                .frame(maxWidth: 540)
        }
        .frame(minWidth: 300, minHeight: 400)
        // 初始选中项同步：view 出现时从控制器读取，并同步到窗口标题
        .onAppear {
            localSelection = controller.selectedPane
            NSApp.keyWindow?.title = localSelection
        }
        // 用户点击侧栏 → 写入控制器 + 更新窗口标题
        .onChange(of: localSelection) { newValue in
            controller.selectedPane = newValue
            NSApp.keyWindow?.title = newValue
        }
        // 外部 showPane() 调用 → 控制器 selectedPane 变化 → 同步到本地
        .onReceive(controller.$selectedPane) { newValue in
            guard localSelection != newValue else { return }
            localSelection = newValue
        }
    }

    /// Liquid Glass 风格侧栏行 — 彩色渐变圆角徽章 + 文字
    @ViewBuilder
    private func row(for pane: PaneItem) -> some View {
        Label {
            Text(pane.title)
        } icon: {
            Image(systemName: pane.icon)
                                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 6))
        }
        .tag(pane.id)
    }

    @ViewBuilder
    private func detail(for id: String) -> some View {
        switch id {
        case "基本": GeneralPane()
        case "标点符号": PunctuationPane()
        case "用户词库": UserDictPane()
        case "应用": ApplicationPane()
        case "主题": ThemePane()
        case "统计": StatisticsPane()
        case "高级": ThesaurusPane()
        default: GeneralPane()
        }
    }
}
