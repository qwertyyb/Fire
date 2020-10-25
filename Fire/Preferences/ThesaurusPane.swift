//
//  ThesaurusPane.swift
//  Fire
//
//  Created by 虚幻 on 2020/10/25.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import SwiftUI
import Preferences

struct ThesaurusPane: View {
    var body: some View {
        Preferences.Container(contentWidth: 450.0) {
            Preferences.Section(title: "") {
                Button(action: {
                    Fire.shared.close()
                    buildDict()
                    Fire.shared.prepareStatement()
                }, label: {
                    Text("重建索引")
                })
            }
        }
    }
}

struct ThesaurusPane_Previews: PreviewProvider {
    static var previews: some View {
        ThesaurusPane()
    }
}
