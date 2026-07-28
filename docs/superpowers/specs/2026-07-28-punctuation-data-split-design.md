# 标点映射与下拉选项数据拆分

日期：2026-07-28  
状态：已确认设计，待实现

## 问题

`punctuation`（`PunctuationConversion.swift`）同时承担：

1. 全角标点方案映射（`.zhhans`）
2. `customPunctuationSettings` 的默认值
3. 设置面板下拉选项的一部分来源（再叠加 `PunctuationPane` 内的 `extraParisOptions`）

改默认映射会牵动 UI 选项拼装逻辑，改下拉候选又要回头看映射表，维护成本高。

## 目标

把「映射方案」和「面板下拉候选」拆成两份独立数据，各改各的；运行时行为与当前一致。

## 非目标

- 不改变标点转换 / 成对输出 / 引号轮换逻辑
- 不迁移已有用户的 `customPunctuationSettings`
- 不新增可配置项或新 UI

## 方案

同文件职责分离 + 面板侧独立选项表（已选）：

| 常量 | 位置 | 类型 | 职责 |
|------|------|------|------|
| `fullwidthPunctuation` | `PunctuationConversion.swift` | `[String: String]` | 全角方案；自定义设置默认值；是否可转换标点键 |
| `punctuationPickerOptions` | `PunctuationPane.swift` | `[String: [String]]` | 每个按键的完整下拉候选 |

不采用「选项表为首选推导默认映射」——避免下拉顺序绑死默认行为。

## 数据内容

### `fullwidthPunctuation`

内容与现有 `punctuation` 字典相同，仅改名。键为 ASCII 半角字符，值为全角（或原样）输出。

### `punctuationPickerOptions`

- 键集合与 `fullwidthPunctuation` 对齐
- 每键列表**显式写全**，不从映射表推导
- 删除 `extraParisOptions`；其内容并入对应键的列表
- 去重；推荐顺序：半角自身 → 当前全角默认 → 原额外候选

当前等价内容（实现时按此落地）：

```
, → [",", "，"]
. → [".", "。"]
/ → ["/", "、"]
; → [";", "；"]
' → ["'", "‘"]
[ → ["[", "【", "「", "『", "〔"]
] → ["]", "】", "」", "』", "〕"]
` → ["`"]
! → ["!", "！"]
@ → ["@"]
# → ["#"]
$ → ["$", "￥"]
% → ["%", "％"]
^ → ["^", "……"]
& → ["&"]
* → ["*", "＊"]
( → ["(", "（"]
) → [")", "）"]
- → ["-"]
_ → ["_", "——"]
+ → ["+"]
= → ["="]
~ → ["~", "～"]
{ → ["{", "「", "【", "『", "〔"]
\ → ["\\", "、"]
| → ["|", "｜"]
} → ["}", "」", "】", "』", "〕"]
: → [":", "："]
" → ["\"", "“"]
< → ["<", "《", "「", "『", "【", "〔"]
> → [">", "》", "」", "』", "】", "〕"]
? → ["?", "？"]
```

说明：`[` 的全角默认是 `【`，额外选项为 `「『〔`；`{` 的全角默认是 `「`，额外为 `【『〔`。列表顺序按「半角 → 默认 → 额外」展开后去重。

## 调用点改动

1. **`PunctuationConversion.conversion`**  
   所有 `punctuation[...]` 改为 `fullwidthPunctuation[...]`。

2. **`DefaultsKeys.customPunctuationSettings`**  
   `default: punctuation` → `default: fullwidthPunctuation`。

3. **`PunctuationPane`**  
   - 新增 `punctuationPickerOptions`  
   - 删除 `extraParisOptions`  
   - Picker：`ForEach(punctuationPickerOptions[key] ?? [], id: \.self)`  
   - 不再拼半角 / `punctuation[key]` / `extraParisOptions`

## 行为保证

- `.zhhans` / `.enUs` / `.custom` 转换结果不变
- 自定义面板可选集合与现网一致（半角 + 全角默认 + 原 extra）
- 已安装用户的 `customPunctuationSettings` 仍读 Defaults，不受默认常量改名影响

## 测试建议

- 手动：全角模式下常用标点（`,` `.` `!` `Shift+数字` 等）输出正确
- 手动：自定义模式下打开各键下拉，选项与改前一致；改一项后上屏生效
- 编译：无对旧名 `punctuation` 的残留引用（文档除外）
