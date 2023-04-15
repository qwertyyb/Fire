//
//  PunctuationPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/6/27.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences
import Defaults

struct PunctuationPane: View {
    @Default(.punctuationMode) private var punctuationMode
    @Default(.customPunctuationSettings) private var customPunctuationSettings
    @Default(.enableDotAfterNumber) private var enableDotAfterNumber
    var body: some View {
        Preferences.Container(contentWidth: 450) {
            Preferences.Section(title: "") {
                HStack {
                    Picker("标点符号方案", selection: $punctuationMode) {
                        Text("半角").tag(PunctuationMode.enUs)
                        Text("全角").tag(PunctuationMode.zhhans)
                        Text("自定义").tag(PunctuationMode.custom)
                    }
                    Spacer(minLength: 150)
                }
                HStack {
                    Toggle("数字后输入 “。”自动转为 “.”", isOn: $enableDotAfterNumber)
                }
                VStack(alignment: .leading) {
                    Text("自定义符号")
                    Spacer(minLength: 4)
                    VStack {
                        HStack {
                            Text("按键")
                                .frame(width: 200, alignment: .center)
                            Text("输出")
                                .frame(width: 200, alignment: .center)
                        }
                        ScrollView {
                            ForEach(
                                customPunctuationSettings.sorted(by: <),
                                id: \.key) { (key, value) -> AnyView in
                                AnyView(HStack(spacing: 0) {
                                    Text(key)
                                        .frame(width: 200, alignment: .center)
                                    Picker("", selection: Binding<String>(
                                        get: { value },
                                        set: {
                                            customPunctuationSettings[key] = $0
                                        }
                                    )) {
                                        Text(key)
                                            .tag(key)
                                        Text(punctuation[key]!)
                                            .tag(punctuation[key]!)
                                    }
                                    .frame(width: 200, alignment: .center)
                                })
                            }
                                .padding(EdgeInsets(top: 6, leading: 20, bottom: 10, trailing: 20))
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding(.top, 4)
                    .background(Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 0.2))
                }
                .disabled(punctuationMode != .custom)
            }
        }
    }
}

struct PunctuationPane_Previews: PreviewProvider {
    static var previews: some View {
        PunctuationPane()
    }
}
