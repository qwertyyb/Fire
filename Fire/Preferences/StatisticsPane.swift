//
//  StatisticsPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/5/22.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences

func formatCount(_ count: Int64) -> String {
    return NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
}

struct CountCircle: View {
    let data: DateCount

    @State private var hovered = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 80,
                        dash: [],
                        dashPhase: 0
                    )
                )
                .frame(width: 10, height: 10, alignment: .center)
                .foregroundColor(Color(red: 251/255, green: 82/255, blue: 0))
                .background(Color.white)
                .cornerRadius(5)
                .scaleEffect(hovered ? 1.3 : 1)
                .onHover { state in
                    hovered = state
                }
                .popover(isPresented: $hovered) {
                    Text("\(data.date)输入: \(formatCount(data.count))字")
                        .padding(6)
                }
        }
    }
}

class DateCountData: ObservableObject {
    @Published var data: [DateCount] = []
    @Published var total: Int64 = 0

    private var observer: Any?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: Statistics.updated,
            object: nil
        )
    }

    deinit {
        guard let observer = self.observer else {
            return
        }
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
    }

    @objc func refresh() {
        NSLog("[DateCountData] refresh start")
        data = Statistics.shared.queryCountByDate()
        total = Statistics.shared.queryTotalCount()
    }
}

struct StatisticsPane: View {
    @ObservedObject var dateCountData = DateCountData()

    func getPath(geo: GeometryProxy) -> Path {
        return Path { path in
            let data = dateCountData.data
            let maxVal = data.reduce(0) { (res, dateCount) -> Int64 in
                return max(res, dateCount.count)
            }
            let scale = geo.size.height / CGFloat(maxVal)
            let gap = data.count > 1
                ? (geo.size.width - 16) / CGFloat(data.count - 1)
                : 0

            path.move(to: CGPoint(x: 8, y: geo.size.height - CGFloat((data[0].count)) * scale))

            data.enumerated().forEach { element in
                path.addLine(
                    to: CGPoint(
                        x: 8 + CGFloat(element.offset) * gap,
                        y: geo.size.height - CGFloat(element.element.count) * scale
                    )
                )
            }

            path.addLine(to: CGPoint(x: 8 + CGFloat(data.count - 1) * gap, y: geo.size.height))
            path.addLine(to: CGPoint(x: 8, y: geo.size.height))
            path.closeSubpath()
        }
    }

    func drawLogPoints(data: [DateCount]) -> some View {
        return GeometryReader { geo in
            let maxNum = data.reduce(0) { (res, item) -> Int64 in
                return max(res, item.count)
            }

            let scale = geo.size.height / CGFloat(maxNum)
            let gap = data.count > 1
                ? (geo.size.width - 16) / CGFloat(data.count - 1)
                : 0

            ForEach(Array(data.enumerated()), id: \.element) { (offset, element) in
                CountCircle(data: element)
                    .offset(
                        x: 8 + gap * CGFloat(offset) - 5,
                        y: (geo.size.height - (CGFloat(element.count) * scale)) - 5
                    )
            }
        }
    }

    func drawBackground(data: [DateCount]) -> some View {
        return GeometryReader { geo in
            Path { path in
                let data = dateCountData.data
                let gap = data.count > 1
                    ? (geo.size.width - 16) / CGFloat(data.count - 1)
                    : 0

                (0..<data.count).forEach { element in
                    path.move(to: CGPoint(x: 8 + CGFloat(element) * gap, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 8 + CGFloat(element) * gap, y: 0))
                }
            }
            .stroke(
                style: StrokeStyle(
                    lineWidth: 1,
                    lineCap: .round,
                    lineJoin: .round,
                    miterLimit: 80,
                    dash: [],
                    dashPhase: 0
                )
            )
            .foregroundColor(Color.black.opacity(0.5))
        }
    }

    var body: some View {
        Preferences.Container(contentWidth: 450) {
            Preferences.Section(title: "") {
                VStack(alignment: .leading) {
                    GroupBox {
                        HStack {
                            Text("\(formatCount(dateCountData.total))字")
                            Spacer()
                        }
                    } label: {
                        Text("累计输入")
                    }

                    GroupBox {
                        GeometryReader { geo in
                            getPath(geo: geo)
                                .fill(Color.red.opacity(0.2))
                        }
                        .frame(height: 320)
                        .overlay(drawBackground(data: dateCountData.data))
                        .overlay(GeometryReader(content: { geo in
                            getPath(geo: geo)
                                .stroke(
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        lineCap: .round,
                                        lineJoin: .round,
                                        miterLimit: 80,
                                        dash: [],
                                        dashPhase: 0
                                    )
                                )
                                .foregroundColor(Color(red: 251/255, green: 82/255, blue: 0).opacity(0.6))
                        }))
                        .overlay(drawLogPoints(data: dateCountData.data))
                        .background(Color.yellow.opacity(0.1))
                        HStack {
                            ForEach(Array(dateCountData.data.enumerated()), id: \.element) { (offset, element) in
                                Text(element.date)
                                if offset < dateCountData.data.count - 1 {
                                    Spacer()
                                }
                            }
                        }
                        Spacer(minLength: 20)
                        Text("近五天内输入情况统计")
                    } label: {
                        Text("统计数据")
                    }
                }
            }
        }
    }
}

struct StatisticsPane_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsPane()
    }
}
