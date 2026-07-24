//
//  KeyCap.swift
//  Fire
//
//  Created by 虚幻 on 2025/7/11.
//  Copyright © 2025 qwertyyb. All rights reserved.
//

import SwiftUI

/// 按键帽样式：可选 SF Symbol 图标 + 标签文字
struct KeyCap: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Group {
            if let icon {
                HStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.caption2)
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            } else {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 0.2))
        .cornerRadius(3)
    }
}

#Preview {
    HStack(spacing: 6) {
        KeyCap("control", icon: "control")
        Text("+").font(.caption2).foregroundStyle(.tertiary)
        KeyCap("=")
        Text("说明文字").font(.caption2).foregroundStyle(.tertiary)
    }
    .padding()
}
