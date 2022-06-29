//
//  PunctutionPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/6/27.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences
import Defaults

struct PunctutionPane: View {
    @Default(.punctutionMode) private var punctutionMode
    @Default(.customPunctutionSettings) private var customPunctutionSettings
    var body: some View {
        Preferences.Container(contentWidth: 450) {
            Preferences.Section(title: "") {
                HStack {
                    Picker("标点符号方案", selection: $punctutionMode) {
                        Text("半角").tag(PunctutionMode.enUs)
                        Text("全角").tag(PunctutionMode.zhhans)
                        Text("自定义").tag(PunctutionMode.custom)
                    }
                    Spacer(minLength: 150)
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
                                customPunctutionSettings.sorted(by: <),
                                id: \.key) { (key, value) -> AnyView in
                                AnyView(HStack(spacing: 0) {
                                    Text(key)
                                        .frame(width: 200, alignment: .center)
                                    Picker("", selection: Binding<String>(
                                        get: { value },
                                        set: {
                                            customPunctutionSettings[key] = $0
                                        }
                                    )) {
                                        Text(key)
                                            .tag(key)
                                        Text(punctution[key]!)
                                            .tag(punctution[key]!)
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
                .disabled(punctutionMode != .custom)
            }
        }
    }
}

struct PunctutionPane_Previews: PreviewProvider {
    static var previews: some View {
        PunctutionPane()
    }
}
