//
//  PunctutionPane.swift
//  Fire
//
//  Created by 虚幻 on 2022/6/27.
//  Copyright © 2022 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences

struct PunctutionItem: Identifiable {
    let id = UUID()
    let input: String
    let output: String
}

struct PunctutionPane: View {
    let data = [
        PunctutionItem(input: "+", output: "＋"),
        PunctutionItem(input: "-", output: "－")
    ]
    @State private var selected = "b"
    var body: some View {
        Preferences.Container(contentWidth: 450) {
            Preferences.Section(title: "") {
                GroupBox(label: Text("标点符号")) {
                    HStack {
                        Text("按键")
                            .frame(width: 200, alignment: .center)
                        Text("输出")
                            .frame(width: 200, alignment: .center)
                    }
                    List(data) { item in
                        VStack {
                            HStack(spacing: 0) {
                                Text(item.input)
                                    .frame(width: 200, alignment: .center)
                                Text(item.output)
                                    .frame(width: 200, alignment: .center)
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct PunctutionPane_Previews: PreviewProvider {
    static var previews: some View {
        PunctutionPane()
    }
}
