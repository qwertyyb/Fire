import AppKit
import Defaults
import SwiftUI

// MARK: - 主题列表

struct ThemeConfigView: View {
    let themeConfig: ThemeConfig
    let isUsing: Bool
    let use: () -> Void
    var onEdit: (() -> Void)?
    var onExport: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(themeConfig.name)
                        .font(.system(size: 13, weight: .medium))
                    if isUsing {
                        Text("使用中")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                    }
                }
                Text("ID: \(themeConfig.id) · \(themeConfig.author)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                if let onEdit = onEdit {
                    Button("编辑", action: onEdit).controlSize(.small)
                }
                if let onExport = onExport {
                    Button("导出", action: onExport).controlSize(.small)
                }
                if let onDelete = onDelete {
                    Button("删除", action: onDelete).controlSize(.small)
                }
                Button(isUsing ? "正使用" : "使用") { use() }
                    .disabled(isUsing)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }
}

// MARK: - 偏好设置面板（迁移自 Settings 库，改用原生 ScrollView + VStack）

struct ThemePane: View {
    @Default(.themeConfig) var themeConfig
    @Default(.importedThemeConfig) var importedThemeConfig
    @State private var editingTheme: ThemeConfig?
    @State private var confirmDeleteTheme: ThemeConfig?
    fileprivate static var editorWindow: NSWindow?
    fileprivate static let editorDelegate = EditorCloseHandler()
    fileprivate class EditorCloseHandler: NSObject, NSWindowDelegate {
        func windowWillClose(_: Notification) { ThemeEditorView.closePreview() }
    }

    private func openEditor() {
        ThemeEditorView.closePreview()
        ThemePane.editorWindow?.close()
        let host = NSHostingView(
            rootView: ThemeEditorView(existing: editingTheme)
        )
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 650),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "主题编辑器"
        win.contentView = host
        win.center()
        win.makeKeyAndOrderFront(nil)
        win.isReleasedWhenClosed = false
        win.delegate = Self.editorDelegate
        ThemePane.editorWindow = win
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Button("创建主题") {
                        editingTheme = nil
                        openEditor()
                    }
                    Spacer()
                    Button("导入") {
                        let p = NSOpenPanel()
                        p.allowedContentTypes = [.json]
                        guard p.runModal() == .OK,
                            let d = p.url.flatMap({
                                try? String(contentsOf: $0, encoding: .utf8)
                            }),
                            case .success(let c) = parseThemeConfig(jsonData: d)
                        else { return }
                        applyImportedTheme(c)
                    }
                }
            } header: {
                Text("主题管理")
            }
            Section {
                ThemeConfigView(
                    themeConfig: defaultThemeConfig,
                    isUsing: themeConfig.id == defaultThemeConfig.id,
                    use: { Defaults[.themeConfig] = defaultThemeConfig }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        // 当前使用 → 彩色粗边框(lineWidth:2)；未使用 → 灰色细边框(lineWidth:1)
                        .stroke(
                            themeConfig.id == defaultThemeConfig.id
                                ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: themeConfig.id == defaultThemeConfig.id
                                ? 2 : 1
                        )
                )
            } header: {
                Text("默认主题")
            }
            if !Defaults[.importedThemeConfigs].isEmpty {
                Section {
                    VStack(spacing: 8) {
                        ForEach(Defaults[.importedThemeConfigs], id: \.id) {
                            t in
                            ThemeConfigView(
                                themeConfig: t,
                                isUsing: t.id == themeConfig.id,
                                use: { Defaults[.themeConfig] = t },
                                onEdit: {
                                    editingTheme = t
                                    openEditor()
                                },
                                onExport: {
                                    guard let json = jsonThemeConfig(config: t)
                                    else { return }
                                    let panel = NSSavePanel()
                                    panel.allowedContentTypes = [.json]
                                    panel.nameFieldStringValue =
                                        "\(t.name)-\(t.id)-\(t.author).json"
                                    guard panel.runModal() == .OK,
                                        let url = panel.url
                                    else { return }
                                    try? json.write(
                                        to: url,
                                        atomically: true,
                                        encoding: .utf8
                                    )
                                },
                                onDelete: {
                                    confirmDeleteTheme = t
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        t.id == themeConfig.id
                                            ? Color.accentColor
                                            : Color.gray.opacity(0.3),
                                        lineWidth: t.id == themeConfig.id
                                            ? 2 : 1
                                    )
                            )
                            Divider()
                        }
                    }
                } header: {
                    Text("自定义主题")
                }
            }
        }
        .formStyle(.grouped)
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { confirmDeleteTheme != nil },
                set: { if !$0 { confirmDeleteTheme = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let t = confirmDeleteTheme {
                    if Defaults[.themeConfig].id == t.id {
                        Defaults[.themeConfig] = defaultThemeConfig
                    }
                    Defaults[.importedThemeConfigs].removeAll { $0.id == t.id }
                    if Defaults[.importedThemeConfig]?.id == t.id {
                        Defaults[.importedThemeConfig] = nil
                    }
                }
                confirmDeleteTheme = nil
            }
            Button("取消", role: .cancel) { confirmDeleteTheme = nil }
        } message: {
            if confirmDeleteTheme != nil {
                Text("删除后无法恢复，若当前正在使用该主题，将回退到默认主题。")
            }
        }
    }

}

// MARK: - 主题编辑器

struct ThemeEditorView: View {
    @State private var editingDark = false
    @State private var showVerticalPreview = false
    @State private var syncSliders = true
    @State private var name = ""
    @State private var id = ""
    @State private var author = NSFullUserName()
    @State private var light = defaultThemeConfig.light
    @State private var dark =
        defaultThemeConfig.dark ?? defaultThemeConfig.light
    @Environment(\.presentationMode) var pm

    private static var previewWindow: NSWindow?

    init(existing: ThemeConfig? = nil) {
        if let e = existing {
            _name = State(initialValue: e.name)
            _id = State(initialValue: e.id)
            _author = State(initialValue: e.author)
            _light = State(initialValue: e.light)
            _dark = State(initialValue: e.dark ?? e.light)
        } else {
            _id = State(
                initialValue: String(UUID().uuidString.prefix(8).lowercased())
            )
        }
    }

    private func updatePreviewWindow() {
        NSLog("[ThemeEditor] updatePreviewWindow")
        // 关闭旧窗口后重建（避免替换 contentView 导致的 AppKit 状态问题）
        Self.closePreview()
        let config = editingDark ? dark : light
        let demo: [Candidate] = [
            Candidate(code: "a", text: "工", type: CandidateType.wb),
            Candidate(code: "a", text: "戈", type: CandidateType.wb),
            Candidate(code: "aa", text: "式", type: CandidateType.wb),
            Candidate(code: "aa", text: "戒", type: CandidateType.wb),
            Candidate(code: "aaad", text: "工期", type: CandidateType.wb),
        ]
        let preview = CandidatesView(
            candidates: demo,
            origin: "a",
            previewConfig: config,
            previewDirection: showVerticalPreview ? .vertical : .horizontal
        )
        let host = NSHostingView(rootView: preview)
        host.wantsLayer = true
        host.layer?.cornerRadius = CGFloat(config.windowBorderRadius)
        host.layer?.masksToBounds = true

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.contentView = host
        win.title = "候选栏预览"
        // 定位在编辑器窗口右侧
        if let editorWin = NSApp.keyWindow {
            let editorFrame = editorWin.frame
            win.setFrameTopLeftPoint(
                NSPoint(x: editorFrame.maxX + 20, y: editorFrame.maxY)
            )
        } else {
            win.center()
        }
        win.makeKeyAndOrderFront(nil)
        Self.previewWindow = win
        NSLog("[ThemeEditor] preview window opened at \(win.frame)")
    }

    /// 隐藏预览浮窗（不释放窗口，仅移出屏幕并释放内部视图）
    fileprivate static func closePreview() {
        previewWindow?.orderOut(nil)
        previewWindow?.contentView = nil
    }

    private func closePreviewWindow() {
        Self.closePreview()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: 基本信息 + 模式切换
                    HStack(alignment: .top, spacing: 16) {
                        GroupBox {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("名称").frame(width: 40, alignment: .trailing)
                                    TextField("", text: $name).frame(maxWidth: .infinity)
                                }
                                HStack {
                                    Text("编号").frame(width: 40, alignment: .trailing)
                                    TextField("", text: $id).disabled(true).frame(maxWidth: .infinity)
                                }
                                HStack {
                                    Text("作者").frame(width: 40, alignment: .trailing)
                                    TextField("", text: $author).frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.trailing, 10)
                        } label: {
                            Label("基本信息", systemImage: "info.circle")
                        }

                        GroupBox {
                            VStack(spacing: 10) {
                                HStack(spacing: 6) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "sun.max.fill")
                                            .font(.system(size: 14))
                                        Text("浅色").font(.caption2)
                                    }
                                    .foregroundStyle(editingDark ? Color.gray.opacity(0.35) : Color.accentColor)
                                    .frame(width: 60, height: 52)
                                    .background(!editingDark ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingDark = false }
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("浅色")

                                    VStack(spacing: 2) {
                                        Image(systemName: "moon.fill")
                                            .font(.system(size: 14))
                                        Text("深色").font(.caption2)
                                    }
                                    .foregroundStyle(editingDark ? Color.accentColor : Color.gray.opacity(0.35))
                                    .frame(width: 60, height: 52)
                                    .background(editingDark ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingDark = true }
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("深色")
                                    Divider()
                                    VStack(spacing: 2) {
                                        Image(systemName: "text.justify")
                                            .font(.system(size: 14))
                                        Text("横向").font(.caption2)
                                    }
                                    .foregroundStyle(showVerticalPreview ? Color.gray.opacity(0.35) : Color.accentColor)
                                    .frame(width: 60, height: 52)
                                    .background(!showVerticalPreview ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture { showVerticalPreview = false }
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("横向")

                                    VStack(spacing: 2) {
                                        Image(systemName: "text.justify")
                                            .font(.system(size: 14))
                                            .rotationEffect(.degrees(90))
                                        Text("竖向").font(.caption2)
                                    }
                                    .foregroundStyle(showVerticalPreview ? Color.accentColor : Color.gray.opacity(0.35))
                                    .frame(width: 60, height: 52)
                                    .background(showVerticalPreview ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture { showVerticalPreview = true }
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("竖向")
                                }
                                Divider()
                                Toggle("毛玻璃效果", isOn: (editingDark ? $dark : $light).enableLiquidGlass)
                                    .controlSize(.small)
                            }
                        } label: {
                            Label("预览模式", systemImage: "eye")
                        }
                    }

                    // MARK: 颜色
                    colorSection

                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        Label("滑块区", systemImage: "slider.horizontal.3")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Toggle(isOn: $syncSliders) {
                            Text("浅色/深色共享")
                                .font(.caption)
                        }
                        .controlSize(.small)
                        .toggleStyle(.switch)
                    }

                    // MARK: 字体大小
                    GroupBox {
                        VStack(spacing: 10) {
                            sliderRow(label: "正文", value: synced(\.fontSize), range: 10...28)
                            sliderRow(label: "序号", value: synced(\.indexFontSize), range: 10...28)
                            sliderRow(label: "提示码", value: synced(\.codeFontSize), range: 10...28)
                        }
                        .padding(.vertical, 4)
                        .padding(.trailing, 10)
                    } label: {
                        Label("字体大小", systemImage: "textformat.size")
                    }

                    // MARK: 窗口内边距 + 选中高亮内边距
                    HStack(alignment: .top, spacing: 16) {
                        GroupBox {
                            VStack(spacing: 8) {
                                sliderRow(label: "上", value: synced(\.windowPaddingTop), range: 0...20)
                                sliderRow(label: "下", value: synced(\.windowPaddingBottom), range: 0...20)
                                sliderRow(label: "左", value: synced(\.windowPaddingLeft), range: 0...30)
                                sliderRow(label: "右", value: synced(\.windowPaddingRight), range: 0...30)
                            }
                            .padding(.vertical, 2)
                            .padding(.trailing, 10)
                        } label: {
                            Label("窗口内边距", systemImage: "rectangle.inset.filled")
                        }

                        GroupBox {
                            VStack(spacing: 8) {
                                sliderRow(label: "上", value: synced(\.selectedPaddingTop), range: 0...12)
                                sliderRow(label: "下", value: synced(\.selectedPaddingBottom), range: 0...12)
                                sliderRow(label: "左", value: synced(\.selectedPaddingLeft), range: 0...12)
                                sliderRow(label: "右", value: synced(\.selectedPaddingRight), range: 0...12)
                            }
                            .padding(.vertical, 2)
                            .padding(.trailing, 10)
                        } label: {
                            Label("选中高亮内边距", systemImage: "rectangle.expand.vertical")
                        }
                    }

                    // MARK: 间距 + 圆角
                    HStack(alignment: .top, spacing: 16) {
                        GroupBox {
                            VStack(spacing: 8) {
                                sliderRow(label: "输入码", value: synced(\.originCandidatesSpace), range: 0...20)
                                sliderRow(label: "候选项", value: synced(\.candidateSpace), range: 0...20)
                            }
                            .padding(.vertical, 2)
                            .padding(.trailing, 10)
                        } label: {
                            Label("间距", systemImage: "space")
                        }

                        GroupBox {
                            VStack(spacing: 8) {
                                sliderRow(label: "候选栏", value: synced(\.windowBorderRadius), range: 0...24)
                                sliderRow(label: "选中项", value: synced(\.selectedBackgroundRadius), range: 0...12)
                            }
                            .padding(.vertical, 2)
                            .padding(.trailing, 10)
                        } label: {
                            Label("圆角", systemImage: "circle.dotted")
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }

            Divider()
            HStack {
                Spacer()
                Button("保存并应用") { saveTheme() }.keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 640, minHeight: 620)
        .onAppear { updatePreviewWindow() }
        .onDisappear {
            closePreviewWindow()
            ThemePane.editorWindow = nil
        }
        .onChange(of: editingDark) { _ in updatePreviewWindow() }
        .onChange(of: showVerticalPreview) { _ in updatePreviewWindow() }
        .onChange(of: light) { _ in updatePreviewWindow() }
        .onChange(of: dark) { _ in updatePreviewWindow() }
    }

    // MARK: - 颜色区域（分解为独立属性以加速类型检查）
    @ViewBuilder
    private var colorSection: some View {
        let theme = editingDark ? $dark : $light
        GroupBox {
            HStack(alignment: .top, spacing: 0) {
                // 左列
                VStack(spacing: 20) {
                    colorGroup(title: "候选项", hint: "未选中状态") {
                        ColorPickerRow(label: "序号", color: theme.candidateIndexColor)
                        ColorPickerRow(label: "文字", color: theme.candidateTextColor)
                        ColorPickerRow(label: "提示码", color: theme.candidateCodeColor)
                    }
                    colorGroup(title: "候选栏", hint: "窗口背景与输入码") {
                        ColorPickerRow(label: "背景", color: theme.windowBackgroundColor)
                        ColorPickerRow(label: "输入码", color: theme.originCodeColor)
                    }
                }

                // 中间分隔线
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 1)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 4)

                // 右列
                VStack(spacing: 20) {
                    colorGroup(title: "选中项", hint: "当前高亮候选") {
                        ColorPickerRow(label: "序号", color: theme.selectedIndexColor)
                        ColorPickerRow(label: "文字", color: theme.selectedTextColor)
                        ColorPickerRow(label: "提示码", color: theme.selectedCodeColor)
                        ColorPickerRow(label: "背景", color: theme.selectedBackgroundColor)
                    }
                    colorGroup(title: "翻页指示器", hint: "上下翻页箭头") {
                        ColorPickerRow(label: "可用", color: theme.pageIndicatorColor)
                        ColorPickerRow(label: "禁用", color: theme.pageIndicatorDisabledColor)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
        } label: {
            Label("颜色", systemImage: "paintpalette")
        }
    }

    private func colorGroup<Content: View>(title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(.tint)
                    .frame(width: 3, height: 12)
                Text(title).font(.caption).fontWeight(.semibold)
                Text(hint).font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.bottom, 4)
            content()
        }
    }

    // MARK: - 浅色/深色同步绑定（切换配色时滑块值自动对应）
    private func synced<V>(_ keyPath: WritableKeyPath<AppearanceThemeConfig, V>) -> Binding<V> {
        Binding(
            get: { editingDark ? dark[keyPath: keyPath] : light[keyPath: keyPath] },
            set: { newValue in
                light[keyPath: keyPath] = newValue
                if syncSliders { dark[keyPath: keyPath] = newValue }
            }
        )
    }

    // MARK: - 滑块行
    @ViewBuilder
    private func sliderRow(label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 50, alignment: .trailing)
                .font(.system(size: 12))
            HStack(spacing: 0) {
                Slider(value: value, in: range)
                    .frame(minWidth: 80)
                Text("\(Int(value.wrappedValue))")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 24, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .padding(.leading, -2)
            }
        }
    }

    func saveTheme() {
        // 无论当前编辑浅色还是深色模式，始终保存两份独立配置（dark: dark）
        // 避免 editingDark ? dark : nil 导致编辑浅色时丢失深色配置
        let theme = ThemeConfig(
            schemaVersion: 1,
            id: String(id),
            name: name.isEmpty ? "未命名" : name,
            author: author,
            light: light,
            dark: dark
        )
        applyImportedTheme(theme)
        Self.closePreview()
        pm.wrappedValue.dismiss()
    }

}

// MARK: - 颜色选择器

struct ColorPickerRow: View {
    let label: String
    @Binding var color: ColorData

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            ColorPicker("", selection: Binding(
                get: { Color(color) },
                set: {
                    if let c = $0.cgColor?.components, c.count >= 3 {
                        color = ColorData(red: c[0], green: c[1], blue: c[2], opacity: c.count > 3 ? c[3] : 1)
                    }
                }
            )).labelsHidden().controlSize(.mini).frame(width: 24)

            TextField("Hex", text: Binding(
                get: { color.hexString },
                set: { if let d = ColorData(hex: $0) { color = d } }
            ))
            .font(.system(size: 10, design: .monospaced))
            .frame(width: 62)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    ThemePane()
}
