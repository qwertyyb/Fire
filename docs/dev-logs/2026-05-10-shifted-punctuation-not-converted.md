# 全角标点不生效（仅 `,` `.` 转换）问题分析

- 日期：2026-05-10
- 关联 Issue：
  - [#152 在设置里就是全角的，但输入的时候只有逗号和句号是全角的](https://github.com/qwertyyb/Fire/issues/152)
  - [#149 无法输入全角符号](https://github.com/qwertyyb/Fire/issues/149)
- 影响范围：`PunctuationMode == .zhhans`（默认）以及 `.custom` 模式下，所有需要 `Shift` 组合键才能输入的标点符号。
- 影响版本：当前 `main` 分支（HEAD：`80e1d01`）。
- 历史回归源：commit `2d66064`（`fix: 修复禁止切换中英文后，在 chrome 浏览器或 electron 应用中快捷捷无法使用的问题 #132`，2024-11-30）。该 commit 在修 #132 时把 `flagChangedHandler` 中原本存在的 `event.modifierFlags != .shift` 例外条款删除了，从此 Shift 组合键被一律拦截。
- 修复 commit：见仓库 git log（包含 `flagChangedHandler` 的 mask 修正）。

## 现象

在「首选项 → 标点符号」中将方案设为「全角」后，实际输入时只有 `,` 和 `.` 会被转换为 `，` 和 `。`，而 `?` `!` `:` `"` `<` `>` `(` `)` `^` 等需要 `Shift` 才能打出的符号全部以半角形式直接落到目标输入框，没有进入输入法的标点转换流程。

issue #149 报告者描述："标点符号即使设置为全角，有些符号也不支持，比如 `?<>()!^:`。似乎只有逗号和句号好使。"

## 事件分发链概览

`FireInputController.handle(_:client:)` 把 `NSEvent` 顺序交给一组 handler 处理，任何 handler 返回非 `nil` 即终止：

```326:354:Fire/FireInputController.swift
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return false }
        ...
        let handler = Utils.shared.processHandlers(handlers: [
            hotkeyHandler,
            flagChangedHandler,
            enModeHandler,
            predictorHandler,
            pageKeyHandler,
            deleteKeyHandler,
            charKeyHandler,
            numberKeyHandlder,
            escKeyHandler,
            enterKeyHandler,
            spaceKeyHandler,
            punctuationKeyHandler
        ])
        return handler(event) ?? false
    }
```

正常情况下，标点应一路落到链尾的 `punctuationKeyHandler`，由 `PunctuationConversion` 将半角字符转换为对应全角字符（`punctuation` 字典定义在 `Fire/types.swift`）。

## 根因

问题出在排在第二位的 `flagChangedHandler`：

```128:151:Fire/FireInputController.swift
     func flagChangedHandler(event: NSEvent) -> Bool? {
         NSLog("[FireInputController] flagChangedHandler")
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if !Defaults[.disableEnMode] && Utils.shared.toggleInputModeKeyUpChecker.check(event) {
            ...
        }
        // 监听.flagsChanged事件只为切换中英文，其它情况不处理需要返回 false 以避免快捷键不生效
        if event.type == .flagsChanged || (
            event.modifierFlags != .init(rawValue: 0)
            // 输入法需要处理方向键做翻页，所以需要排除方向键
            && event.modifierFlags != .init(arrayLiteral: .numericPad, .function)
        ) {

            NSLog("[FireInputController] flagChangedHandler no need handle")
            return false
        }
        return nil
    }
```

它的初衷是：只要带任何修饰键就直接 `return false`，把事件交还给系统，避免拦截系统快捷键；唯一例外是方向键（`event.modifierFlags == .numericPad | .function`）以便用作翻页。

但中文常用标点几乎全部需要 `Shift`：

| 按键组合 | 输入 | 期望输出（全角） |
| --- | --- | --- |
| Shift+1 | `!` | `！` |
| Shift+2 | `@` | `@` |
| Shift+4 | `$` | `￥` |
| Shift+6 | `^` | `……` |
| Shift+9 / Shift+0 | `(` `)` | `（` `）` |
| Shift+- / Shift+= | `_` `+` | `——` `+` |
| Shift+[ / Shift+] | `{` `}` | `「` `」` |
| Shift+\ | `\|` | `\|` |
| Shift+; | `:` | `：` |
| Shift+' | `"` | `"` |
| Shift+, / Shift+. | `<` `>` | `《` `》` |
| Shift+/ | `?` | `？` |
| Shift+\` | `~` | `~` |

按下这些组合键时，`event.modifierFlags` 含 `.shift`（`rawValue = 0x20000`），既不等于 `0`，也不等于 `.numericPad | .function`，于是 `flagChangedHandler` 直接 `return false`，事件根本走不到链尾的 `punctuationKeyHandler`，系统就把英文半角字符直接送入目标输入框。

`,` 和 `.` 是**无修饰键**（`modifierFlags == 0`），可以顺利穿过 `flagChangedHandler`，最终在 `punctuationKeyHandler` 被 `PunctuationConversion.shared.conversion` 转成 `，` 和 `。`：

```189:222:Fire/types.swift
let punctuation: [String: String] = [
    ",": "，",
    ".": "。",
    "/": "、",
    ";": "；",
    "'": "‘",
    "[": "【",
    "]": "】",
    ...
    "!": "！",
    ...
    "?": "？"
]
```

这就是「设置里是全角、输入时只有 `,` `.` 是全角」的根本原因。

## 几个边角说明

- `;` 即使无 Shift 通过了 `flagChangedHandler`，也会在 `punctuationKeyHandler` 开头被识别为临时英文模式触发器（`DictManager.tempEnTriggerPunctuation = ";"`），不会被转成 `；`。这是已有功能，并非本 bug。
- `-` 和 `=` 在 `punctuation` 字典里映射就是它们自身，转不转换肉眼无差，加上 `pageKeyHandler` 在有候选词时会把它们当翻页键，用户更难感知。
- `/` `'` `[` `]` `` ` `` `\` 这几个无 Shift 标点理论上能正常转换。如果用户实测连这些也没生效，需要单独加日志排查 `event.modifierFlags` 低 16 位是否被设备相关位置位（极少数键盘/驱动场景下会出现），但那是次要问题，本 issue 的主因是 Shift 组合键被一刀切屏蔽。

## 历史脉络

回看 `flagChangedHandler` 的演进对理解修复点很有帮助：

1. **早期版本**：拦截条件是 `modifierFlags != 0 && != .shift && != (.numericPad | .function)`——明确把 Shift 和方向键放行。彼时 `charKeyHandler` 的字母正则是 `^[a-z]+$`，Shift+字母不命中正则、最终回退给系统直接上屏。
2. **commit `0b51393`（2023-11-09）**：把 `charKeyHandler` 的字母正则改为 `^[a-zA-Z]+$`，配合 `flagChangedHandler` 仍然放行 Shift 的事实，**让大写字母被附加到 `_originalString` 进入输入会话，而不再直接上屏**。commit message："考虑到会增加输入负担，中文模式下输入大写字母时，不再直接上屏处理"。
3. **commit `2d66064`（2024-11-30）**：为了修 #132（"禁止切换中英文后，在 chrome 浏览器或 electron 应用中快捷键无法使用"）顺手把 `flagChangedHandler` 重写了一遍，**删掉了 `!= .shift` 这条例外**。从此：
   - 中文常用 Shift+标点不再进入 `punctuationKeyHandler`，全部以半角形式被系统直接上屏 → 即 issue #149 / #152 报告的现象。
   - `0b51393` 引入的"大写字母进会话"行为也连带被废掉了——Shift+字母重新走系统直接上屏。

本次修复实质是恢复 commit `2d66064` 之前对 Shift 的放行设计，同时保留它修 #132 时拓展的其它判断（如把 `disableEnMode` 检查并入 `toggleInputModeKeyUpChecker` 那一支）。

## 修复方案（已实施）

`flagChangedHandler` 真正想拦的是 `Cmd` / `Ctrl` / `Option` 这些用于系统快捷键的修饰键，**`Shift` 不应该归入此类**——它本身就是输入大写字母和"上档"标点的常规组合键。

实施的代码：

```140:162:Fire/FireInputController.swift
        // 监听.flagsChanged事件只为切换中英文，其它情况不处理需要返回 false 以避免快捷键不生效
        // 放行规则：先把 Shift / CapsLock 这类不属于"快捷键修饰键"的位剔除，再要求剩余位
        //   - 为空(无修饰键，如 a、,、.)，或
        //   - 恰好是 .numericPad|.function (方向键、用于翻页)
        // 其它情况（含 Cmd/Ctrl/Option/单独 .function 的 F 键、单独 .numericPad 的数字小键盘等）
        // 全部交给系统处理，避免无谓的 handler 链空跑(predictorHandler 会读 client 的 IPC 状态)。
        // Shift / CapsLock 必须放行的原因：
        //   - Shift+标点是常规中文标点输入路径(Shift+1=! 等)，需要继续走到 punctuationKeyHandler 完成全角转换
        //   - Shift+字母由 charKeyHandler 处理(commit 0b51393 起，大写字母会被附加到原码而不直接上屏)
        // .deviceIndependentFlagsMask 用来过滤低位"设备相关"标志，避免极少数键盘场景下的脏数据误判。
        // 关联 issue #149 #152，回归源 commit 2d66064。
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.shift, .capsLock])
        if event.type == .flagsChanged || (
            !modifiers.isEmpty
            && modifiers != .init(arrayLiteral: .numericPad, .function)
        ) {
            NSLog("[FireInputController] flagChangedHandler no need handle")
            return false
        }
        return nil
    }
```

设计取舍：本来想直接 `subtracting([.shift, .capsLock, .numericPad, .function])` 把四个非快捷键修饰位都剔除让条件最简单，但那样 F 键(`.function` 单独)和数字小键盘(`.numericPad` 单独)也会被放行进入事件链。虽然它们的 `event.characters` 既不在 `punctuation` 字典中、也不命中字母正则，所有 handler 都返回 `nil` 最终仍由系统处理，但 `predictorHandler` 中的 `getPreviousText()` 会向 client 发起 IPC 调用读 `selectedRange / markedRange / attributedSubstring`。这种"为不会被处理的事件白跑 IPC"在性能上影响极小、但在架构上不优雅。所以最终保留了老逻辑里"恰好等于 `.numericPad|.function` 才放行"的精确判断，仅把 Shift/CapsLock 单列出来作为剔除对象。

修复后行为对照：

| 输入 | 老行为 | 新行为 |
| --- | --- | --- |
| `Shift+1` 等上档标点 | 系统直上半角 `!` | 进入 `punctuationKeyHandler` 转为全角 `！` |
| `Shift+字母`（如 `A`） | 系统直上大写 `A` | 进入 `charKeyHandler`，被附加到 `_originalString` 作为原码（**恢复 commit `0b51393` 设计**） |
| `Shift+方向键` | 让给系统（精确等值判断不命中而被拦） | 让给系统（不变；`subtracting` 把 shift 剔掉后剩余位等于 `.numericPad\|.function`） |
| `Cmd+C` / `Cmd+,` 等系统快捷键 | 让给系统 | 让给系统（不变） |
| F1–F12（`.function` 单独） | 让给系统 | 让给系统（不变） |
| 数字小键盘（`.numericPad` 单独） | 让给系统 | 让给系统（不变） |
| 方向键（`.numericPad\|.function`） | 让给系统 / 输入会话中翻页 | 行为不变 |
| 切换中英文输入模式（Shift keyup） | 正常切换 | 正常切换（`toggleInputModeKeyUpChecker` 在前面已处理） |
| `event.modifierFlags` 含低位脏标志 | 极少数情况下被误判为按了修饰键 | 被 `.deviceIndependentFlagsMask` 过滤，不再误判 |

> **注意**：`Shift+字母` 的行为变化来自恢复 commit `0b51393` 的设计——它本来就是项目作者在 2023 年明确选择的行为（把大写字母吸进输入会话避免"输入负担"），只不过被 `2d66064` 顺手回退了。本次修复一并恢复。如果未来收到"中文模式下不希望大写字母被吃进输入会话"的反馈，应该单独在 `charKeyHandler` 加 Shift 判断，而不是在 `flagChangedHandler` 把 Shift 重新拉黑——否则 Shift+标点的全角转换又会失效。

## 备选方案讨论：调整 handler 优先级是否可行？

另一种"看起来更简单"的思路是把 `punctuationKeyHandler` 提到 `flagChangedHandler` 之前，让它先于"修饰键拦截"完成转换。但实际推敲会发现这是个**比当前 bug 副作用更大**的方案，记录如下供后人参考。

`processHandlers` 的语义是任何 handler 返回非 `nil` 即终止，所以"提前 = 抢先截胡"。把 `punctuationKeyHandler` 提到 `flagChangedHandler` 之前会出现以下问题：

### 1. 系统快捷键被吞掉（最严重）

`punctuationKeyHandler` 内部**完全没有判断修饰键**，只看字符是否在 `punctuation` 字典中：

```293:312:Fire/FireInputController.swift
    private func punctuationKeyHandler(event: NSEvent) -> Bool? {
        // 获取输入的字符
        let string = event.characters!
        guard inputMode == .zhhans else { return nil }

        if !Defaults[.disableTempEnMode]
            && _originalString.count <= 0 && string == String(DictManager.shared.tempEnTriggerPunctuation)
                || string != String(DictManager.shared.tempEnTriggerPunctuation)
                    && _originalString.first == DictManager.shared.tempEnTriggerPunctuation {
            _originalString += string
            return true
        }

        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if inputMode == .zhhans, let result = PunctuationConversion.shared.conversion(string) {
            insertText(result)
            return true
        }
        return nil
    }
```

意味着按下：

- `Cmd+,`（绝大多数 macOS App 的「打开偏好设置」快捷键）→ `event.characters == ","` → 直接被转成 `，` 上屏，偏好设置打不开。
- `Cmd+.`（取消/中断）、`Cmd+/`（注释/快捷键提示）、`Cmd+[` `Cmd+]`（前进/后退）、`Cmd+'`、`Shift+Cmd+/` 等同理被吞。
- `Cmd+;`（VSCode/部分 IDE 切换断点等）会被识别为"临时英文模式触发"，进入 `_originalString += ";"`。
- `Ctrl+,` / `Ctrl+.` 等其它带修饰键的组合也一样。

当前 `flagChangedHandler` 用 `event.modifierFlags != 0` 一刀切阻断要解决的核心问题是"只想拦 `Cmd/Ctrl/Option`"，但不小心也拦了 `Shift`。如果反过来把 `punctuationKeyHandler` 提前却不加修饰键判断，就变成"什么都不拦"，严重程度比当前 bug 大得多。

### 2. `event.characters!` 在 `.flagsChanged` 事件上会崩溃

`flagChangedHandler` 当前还承担一项"防御"职责：

```141:149:Fire/FireInputController.swift
        if event.type == .flagsChanged || (
            event.modifierFlags != .init(rawValue: 0)
            && event.modifierFlags != .init(arrayLiteral: .numericPad, .function)
        ) {
            
            NSLog("[FireInputController] flagChangedHandler no need handle")
            return false
        }
```

只要事件是 `.flagsChanged`（按下/松开 Shift/Cmd/Option/Ctrl 本身）就提前 `return false`。结合 `recognizedEvents`，同 App 内 `.flagsChanged` 是会进 `handle(_:)` 的：

```316:324:Fire/FireInputController.swift
    override func recognizedEvents(_ sender: Any!) -> Int {
        // 当在当前应用下输入时　NSEvent.addGlobalMonitorForEvents 回调不会被调用，需要针对当前app, 使用原始的方式处理flagsChanged事件
        let isCurrentApp = client().bundleIdentifier() == Bundle.main.bundleIdentifier
        var events = NSEvent.EventTypeMask(arrayLiteral: .keyDown)
        if isCurrentApp {
            events = NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged)
        }
        return Int(events.rawValue)
    }
```

而 `punctuationKeyHandler` 第一行就是 `let string = event.characters!`。对 `.flagsChanged` 事件，`characters` 通常为 `nil`，**force-unwrap 直接 crash**。当前能跑是因为 `flagChangedHandler` 在它前面把 `.flagsChanged` 拦住了。提前后必须额外加 `event.type != .flagsChanged && event.characters != nil` 判断。

### 3. 「数字后 `.` 自动转半角小数点」会失效

`predictorHandler` 是为了处理 "1.5" 这种小数：

```162:176:Fire/FireInputController.swift
    private func predictorHandler(event: NSEvent) -> Bool? {
        // 在数字后输入。号自动转换为小数点
        if Defaults[.enableDotAfterNumber] && event.keyCode == kVK_ANSI_Period && _lastInputIsNumber {
            insertText(".")
            _lastInputIsNumber = false
            return true
        }
        _lastInputIsNumber = false
        
        _lastInputText = getPreviousText()
        ...
        return nil
    }
```

它**必须早于** `punctuationKeyHandler` 跑——否则 `.` 会先被转成 `。`，"1.5" 变成 "1。5"。

把 `punctuationKeyHandler` 提到 `flagChangedHandler` 前面也就到了 `predictorHandler` 前面，这个特性会回归。

### 4. `_lastInputText` 过期，影响中英文之间的自动空格

`predictorHandler` 还顺手刷新 `_lastInputText = getPreviousText()`，供 `insertText` 在中-英之间插入空格使用：

```403:416:Fire/FireInputController.swift
    func insertText(_ text: String) {
        NSLog("insertText: %@", text)
        if text.count > 0 {
            var newText = text
            if Defaults[.enableWhitespaceBetweenZhEn] && Utils.shared.shouldConcatWithWhitespace(_lastInputText, text) {
                newText = " " + newText
                NSLog("[FireInputController] insertCandidate should append whitespace: \(newText)")
            }
            ...
        }
        clean()
    }
```

`punctuationKeyHandler` 抢在 `predictorHandler` 之前 `return true`，本次按键就不会刷新 `_lastInputText`。下一次插入候选词的空格判断会用到陈旧值，偶发"该加空格没加 / 不该加却加了"。

### 5. 收益其实有限

要安全地把 `punctuationKeyHandler` 提前，必须在它内部补上：

1. 跳过 `Cmd / Ctrl / Option` 修饰键
2. 跳过 `.flagsChanged` 事件
3. 跳过 `kVK_ANSI_Period && _lastInputIsNumber` 这条
4. 至少把 `_lastInputText` 先刷新一遍

加完这些之后，`punctuationKeyHandler` 就承担了一半的 `flagChangedHandler` 职责，而 `flagChangedHandler` 自己仍然要保留——它还有 Shift keyup 切换中英文输入模式的功能：

```131:139:Fire/FireInputController.swift
        if !Defaults[.disableEnMode] && Utils.shared.toggleInputModeKeyUpChecker.check(event) {
            ...
            insertText(_originalString)
            Fire.shared.toggleInputMode()
            return true
        }
```

修饰键判断逻辑分裂到两处，未来排错成本更高。

### 方案对比

| 方案 | 改动量 | 副作用风险 |
| --- | --- | --- |
| 把 `punctuationKeyHandler` 提到 `flagChangedHandler` 之前（不加补丁） | 1 行 | 高：`Cmd+,` 等系统快捷键全失效；`.flagsChanged` 崩溃；小数点功能回归；中英空格逻辑不稳定 |
| 提前 + 在 `punctuationKeyHandler` 里补全修饰键/事件类型/`predictor` 判断 | 中 | 中：修饰键判断逻辑出现在两处，长期维护成本高 |
| 新增专用 `shiftedPunctuationHandler` 插到 `predictorHandler` 之后 | 中 | 低，但语义重复 |
| **直接修 `flagChangedHandler`：把 `Shift/CapsLock/numericPad/function` 从拦截集合里剔除** | 几行 | **最低，事件链原貌不变**（最终选择） |

最终采用第四种：mask 修正最小、副作用面最小、不需要在多处重复修饰键判断。

## 验证清单

修复后建议覆盖以下场景：

- [ ] 在文本编辑器中分别输入 `?` `!` `:` `"` `(` `)` `<` `>` `{` `}` `^` `$` `~` `_` `+` `|` `@` `#` `&` `*`，确认对应字符为全角。
- [ ] 输入 `,` `.` `/` `[` `]` `'` `` ` `` `\` 仍然为全角（不回归）。
- [ ] `Shift+字母` 在中文模式下被附加到 `_originalString` 作为原码（**已恢复 commit `0b51393` 行为**），不再直接以大写英文上屏；切到英文模式后仍直接上屏大写英文。
- [ ] `Cmd+C` / `Cmd+V` / `Cmd+Z` / `Cmd+,` / `Cmd+.` 等系统快捷键不被输入法吞掉。
- [ ] 方向键、`-` `=` 在有候选词时仍可翻页。
- [ ] 临时英文模式（按 `;` 触发）行为不变。
- [ ] `PunctuationMode` 切换为「半角」时所有符号保持半角；切换为「自定义」时按用户配置生效。
- [ ] Chrome / Electron 应用中，`disableEnMode` 开启状态下 `Cmd+C` `Cmd+V` 等快捷键不受影响（回归测试 #132）。
