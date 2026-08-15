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
    static let fixedHeight: CGFloat = 20

    let title: String
    let icon: String?
    let iconOnly: Bool

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
        self.iconOnly = false
    }

    /// 仅显示 modifier 图标，固定高度
    init(icon: String) {
        self.title = ""
        self.icon = icon
        self.iconOnly = true
    }

    var body: some View {
        Group {
            if iconOnly, let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .fontWeight(.medium)
            } else if let icon {
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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, iconOnly ? 0 : 2)
        .frame(minHeight: Self.fixedHeight)
        .frame(height: iconOnly ? Self.fixedHeight : nil)
        .background(Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 0.2))
        .cornerRadius(3)
    }
}

#Preview {
    HStack(spacing: 6) {
        KeyCap(icon: "control")
        Text("+").font(.caption2).foregroundStyle(.tertiary)
        KeyCap("=")
        Text("说明文字").font(.caption2).foregroundStyle(.tertiary)
    }
    .padding()
}
