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

fileprivate let themeSectionPadding: CGFloat = 16

struct ThemeEditorView: View {
    @State private var editingDark = false
    @State private var showVerticalPreview = false
    @State private var darkSameLight = true
    @State private var name = ""
    @State private var themeSchemaVersion = String(schemaVersion)
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
            _darkSameLight = State(initialValue: e.dark == nil || e.dark == e.light)
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
        let config = (darkSameLight || !editingDark) ? light : dark
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

    private var activeTheme: Binding<AppearanceThemeConfig> {
        if darkSameLight || !editingDark { $light } else { $dark }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    basicInfoSection
                    windowSection
                    originCodeSection
                    candidateSection
                    selectedCandidateSection
                    pageIndicatorSection
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
        .onChange(of: darkSameLight) { same in
            if same {
                editingDark = false
                updatePreviewWindow()
            }
        }
        .onChange(of: showVerticalPreview) { _ in updatePreviewWindow() }
        .onChange(of: light) { _ in updatePreviewWindow() }
        .onChange(of: dark) { _ in updatePreviewWindow() }
    }

    @ViewBuilder
    private func sectionContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(themeSectionPadding)
    }

    private func formRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(alignment: .leading)
                .lineLimit(1)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 基础信息

    @ViewBuilder
    private var basicInfoSection: some View {
        GroupBox {
            sectionContent {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        formRow(label: "ID") {
                            TextField("", text: $id)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                        }
                        formRow(label: "主题版本") {
                            TextField("", text: $themeSchemaVersion)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                        }
                    }
                    HStack {
                        formRow(label: "名称") {
                            TextField("", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        formRow(label: "作者") {
                            TextField("", text: $author)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    formRow(label: "预览") {
                        HStack(spacing: 6) {
                            if !darkSameLight {
                                previewModeButton(
                                    icon: "sun.max.fill",
                                    label: "浅色",
                                    isActive: !editingDark
                                ) { editingDark = false }
                                previewModeButton(
                                    icon: "moon.fill",
                                    label: "深色",
                                    isActive: editingDark
                                ) { editingDark = true }
                                Divider().frame(height: 36)
                            }
                            previewModeButton(
                                icon: "text.justify",
                                label: "横向",
                                isActive: !showVerticalPreview
                            ) { showVerticalPreview = false }
                            previewModeButton(
                                icon: "text.justify",
                                label: "竖向",
                                isActive: showVerticalPreview,
                                rotation: 90
                            ) { showVerticalPreview = true }
                        }
                    }
                    formRow(label: "深色配色") {
                        Toggle("深色模式与浅色模式使用同一套配色", isOn: $darkSameLight)
                            .controlSize(.small)
                    }
                }
            }
        } label: {
            Label("基础信息", systemImage: "info.circle")
        }
    }

    // MARK: - 窗口

    @ViewBuilder
    private var windowSection: some View {
        GroupBox {
            sectionContent {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ColorPickerRow(label: "背景", color: activeTheme.windowBackgroundColor)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        formRow(label: "毛玻璃") {
                            Toggle("", isOn: activeTheme.enableLiquidGlass)
                                .labelsHidden()
                                .controlSize(.small)
                                .toggleStyle(.switch)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 10) {
                        numberRow(label: "上边距", value: activeTheme.windowPaddingTop, range: 0...20)
                        numberRow(label: "下边距", value: activeTheme.windowPaddingBottom, range: 0...20)
                        numberRow(label: "左边距", value: activeTheme.windowPaddingLeft, range: 0...30)
                        numberRow(label: "右边距", value: activeTheme.windowPaddingRight, range: 0...30)
                    }
                    HStack(spacing: 10) {
                        numberRow(label: "圆角", value: activeTheme.windowBorderRadius, range: 0...24)
                    }
                }
            }
        } label: {
            Label("窗口", systemImage: "macwindow")
        }
    }

    // MARK: - 原码

    @ViewBuilder
    private var originCodeSection: some View {
        GroupBox {
            sectionContent {
                HStack(spacing: 10) {
                    ColorPickerRow(label: "颜色", color: activeTheme.originCodeColor)
                    Spacer()
                    numberRow(label: "与候选项间距", value: activeTheme.originCandidatesSpace, range: 0...20)
                }
            }
        } label: {
            Label("原码", systemImage: "character.cursor.ibeam")
        }
    }

    // MARK: - 候选词

    @ViewBuilder
    private var candidateSection: some View {
        GroupBox {
            sectionContent {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        numberRow(label: "候选项间距", value: activeTheme.candidateSpace, range: 0...20)
                }
                    HStack(spacing: 10) {
                        ColorPickerRow(label: "序号", color: activeTheme.candidateIndexColor)
                        ColorPickerRow(label: "候选词", color: activeTheme.candidateTextColor)
                        ColorPickerRow(label: "提示码", color: activeTheme.candidateCodeColor)
                    }
                    HStack(spacing: 10) {
                        numberRow(label: "序号字号", value: activeTheme.indexFontSize, range: 10...28)
                        numberRow(label: "候选词字号", value: activeTheme.fontSize, range: 10...28)
                        numberRow(label: "提示码字号", value: activeTheme.codeFontSize, range: 10...28)
                    }
                }
            }
        } label: {
            Label("候选项", systemImage: "list.bullet")
        }
    }

    // MARK: - 候选项选中态

    @ViewBuilder
    private var selectedCandidateSection: some View {
        GroupBox {
            sectionContent {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ColorPickerRow(label: "序号", color: activeTheme.selectedIndexColor)
                        ColorPickerRow(label: "候选词", color: activeTheme.selectedTextColor)
                        ColorPickerRow(label: "提示码", color: activeTheme.selectedCodeColor)
                    }
                    HStack(spacing: 10) {
                        ColorPickerRow(label: "背景", color: activeTheme.selectedBackgroundColor)
                    }
                    HStack {
                        numberRow(label: "圆角", value: activeTheme.selectedBackgroundRadius, range: 0...12)
                    }
                    HStack(spacing: 10) {
                        numberRow(label: "上边距", value: activeTheme.selectedPaddingTop, range: 0...12)
                        numberRow(label: "下边距", value: activeTheme.selectedPaddingBottom, range: 0...12)
                        numberRow(label: "左边距", value: activeTheme.selectedPaddingLeft, range: 0...12)
                        numberRow(label: "右边距", value: activeTheme.selectedPaddingRight, range: 0...12)
                    }
                }
            }
        } label: {
            Label("候选项选中态", systemImage: "checkmark.circle")
        }
    }

    // MARK: - 页面指示器

    @ViewBuilder
    private var pageIndicatorSection: some View {
        GroupBox {
            sectionContent {
                HStack(spacing: 10) {
                    ColorPickerRow(label: "可用", color: activeTheme.pageIndicatorColor)
                    ColorPickerRow(label: "禁用", color: activeTheme.pageIndicatorDisabledColor)
                }
            }
        } label: {
            Label("页面指示器", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - 表单辅助
    private func previewModeButton(
        icon: String,
        label: String,
        isActive: Bool,
        rotation: Double = 0,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .rotationEffect(.degrees(rotation))
            Text(label).font(.caption2)
        }
        .foregroundStyle(isActive ? Color.accentColor : Color.gray.opacity(0.35))
        .frame(width: 60, height: 52)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(label)
    }

    // MARK: - 数字输入行
    @ViewBuilder
    private func numberRow(label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        let intRange = Int(range.lowerBound)...Int(range.upperBound)
        formRow(label: label) {
            TextField("", value: Binding(
                get: { Int(value.wrappedValue.rounded()) },
                set: { newValue in
                    let clamped = min(max(newValue, intRange.lowerBound), intRange.upperBound)
                    value.wrappedValue = Float(clamped)
                }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .font(.body)
            .frame(width: 60)
        }
    }

    func saveTheme() {
        let theme = ThemeConfig(
            schemaVersion: schemaVersion,
            id: String(id),
            name: name.isEmpty ? "未命名" : name,
            author: author,
            light: light,
            dark: darkSameLight ? light : dark
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
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(alignment: .trailing)
                .lineLimit(1)

            HStack(spacing: 4) {
                ColorPicker("", selection: Binding(
                    get: { Color(color) },
                    set: {
                        if let c = $0.cgColor?.components, c.count >= 3 {
                            color = ColorData(red: c[0], green: c[1], blue: c[2], opacity: c.count > 3 ? c[3] : 1)
                        }
                    }
                ))
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 24)

                TextField("Hex", text: Binding(
                    get: { color.hexString },
                    set: { if let d = ColorData(hex: $0) { color = d } }
                ))
                .frame(width: 100)
                .font(.system(size: 10, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
    }
}

#Preview {
    ThemePane()
}
