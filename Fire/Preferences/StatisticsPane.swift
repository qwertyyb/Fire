//
//  StatisticsPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/5/22.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Charts
import Defaults
import Combine

func formatCount(_ count: Int64) -> String {
    return NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
}

class DateCountData: ObservableObject {
    @Published var startDate = Date().addingTimeInterval(-5 * 24 * 60 * 60)
    @Published var endDate = Date()
    @Published var data: [DateCount] = []
    @Published var total: Int64 = 0
    @Published var avgCodeLen: Double = 0
    @Published var isLoading = false

    var cancellables = Set<AnyCancellable>()
    /// 避免快速切换日期 / 连续 notification 时旧查询结果覆盖新结果
    private var refreshGeneration = 0

    init() {
        refresh()
        NotificationCenter.default
            .publisher(for: Statistics.updated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        // dropFirst：跳过订阅时的立即发射，避免 init 内重复查图
        $startDate
            .dropFirst()
            .sink { [weak self] date in
                self?.refreshData(startDate: date, endDate: nil)
            }
            .store(in: &cancellables)
        $endDate
            .dropFirst()
            .sink { [weak self] date in
                self?.refreshData(startDate: nil, endDate: date)
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { cancellable in
            cancellable.cancel()
        }
        cancellables = []
    }

    @objc func refresh() {
        NSLog("[DateCountData] refresh start: \(startDate)")
        if !FirePreferencesController.shared.isVisible {
            NSLog("[DateCountData] refresh cancel: not visible")
            return
        }
        let start = startDate
        let end = endDate
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let snapshot = Statistics.shared.queryPaneSnapshot(startDate: start, endDate: end)
            DispatchQueue.main.async {
                guard let self, generation == self.refreshGeneration else { return }
                self.total = snapshot.total
                self.avgCodeLen = snapshot.avgCodeLen
                self.data = snapshot.data
                self.isLoading = false
            }
        }
    }

    func refreshData(startDate: Date?, endDate: Date?) {
        if !FirePreferencesController.shared.isVisible { return }
        let start = startDate ?? self.startDate
        let end = endDate ?? self.endDate
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = Statistics.shared.queryCountByDate(startDate: start, endDate: end)
            DispatchQueue.main.async {
                guard let self, generation == self.refreshGeneration else { return }
                self.data = data
                self.isLoading = false
            }
        }
    }

    func clear() {
        Statistics.shared.clear()
    }
}

// MARK: - 偏好设置面板（迁移自 Settings 库，改用原生 ScrollView + VStack）

struct StatisticsPane: View {
    @StateObject var dateCountData = DateCountData()
    @Default(.enableStatistics) private var enableStatistics
    @State private var showAlert = false

    /// 使用 Swift Charts 框架绘制的折线统计图
    /// 替换原先 80 行自定义 Path+GeometryReader 手工绘图方案
    @ViewBuilder
    private var chartView: some View {
        let data = dateCountData.data
        Chart(data, id: \.date) { item in
            AreaMark(
                x: .value("日期", item.date),
                y: .value("字数", item.count)
            )
            .foregroundStyle(
                LinearGradient(colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.02)],
                               startPoint: .top, endPoint: .bottom)
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("日期", item.date),
                y: .value("字数", item.count)
            )
            .foregroundStyle(Color(red: 251/255, green: 82/255, blue: 0))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("日期", item.date),
                y: .value("字数", item.count)
            )
            .foregroundStyle(Color(red: 251/255, green: 82/255, blue: 0))
            .symbolSize(40)
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let dateStr = value.as(String.self) {
                    AxisValueLabel(dateStr.dropFirst(5))
                }
            }
        }
        .chartPlotStyle { $0.background(Color.yellow.opacity(0.06)) }
        .frame(height: 250)
    }

    var body: some View {
        Form {
            Section {
                Toggle("启用统计", isOn: $enableStatistics)
                HStack {
                    Spacer()
                    Button("清除数据", role: .destructive) {
                        dateCountData.clear()
                        showAlert = true
                    }
                    .disabled(!enableStatistics)
                    .controlSize(.small)
                    .alert("清除成功", isPresented: $showAlert, actions: {})
                }
            } header: {
                Text("统计设置")
            }
            Section {
                if dateCountData.isLoading && dateCountData.total == 0 {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在加载统计…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 18) {
                        Text("\(formatCount(dateCountData.total)) 字")
                            .font(.title)
                            .fontWeight(.bold)
                        if dateCountData.total > 0 {
                            VStack(spacing: 4) {
                                Text("平均码长")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.2f", dateCountData.avgCodeLen))
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                        }
                        if dateCountData.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    if dateCountData.total > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("计算公式：平均码长 = (总编码按键数 + 确认键次数) / 上屏总字数")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            HStack {
                                Text("确认键：手动选择上屏操作，如空格、数字、")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(";'")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 0.2))
                                    .cornerRadius(3)
                                Text("或")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(",.")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 0.2))
                                    .cornerRadius(3)
                                Text("二三候选词上屏符")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("满 4 码自动上屏，不算确认键")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption2)
                        .padding(.top, 2)
                    }
                }
            } header: {
                Text("累计输入")
            }
            Section {
                HStack {
                    DatePicker("开始日期", selection: $dateCountData.startDate, displayedComponents: [.date])
                    DatePicker("结束日期", selection: $dateCountData.endDate, displayedComponents: [.date])
                }
                if dateCountData.isLoading && dateCountData.data.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("正在加载…")
                        Spacer()
                    }
                    .frame(minHeight: 200)
                } else if dateCountData.data.isEmpty {
                    HStack {
                        Spacer()
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(minHeight: 200)
                } else {
                    chartView
                        .opacity(dateCountData.isLoading ? 0.45 : 1)
                        .overlay {
                            if dateCountData.isLoading {
                                ProgressView()
                            }
                        }
                }
            } header: {
                Text("输入统计")
            }
        }
        .formStyle(.grouped)
    }
}

// 采用 Xcode 15 引入的 #Preview 宏语法，替代旧版 PreviewProvider 协议，使预览代码更简洁直观。
#Preview {
    StatisticsPane()
}
