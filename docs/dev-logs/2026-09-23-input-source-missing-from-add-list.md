# 首次安装后未出现在「添加输入法」候选列表

- 日期：2026-09-23
- 现象：安装完成后，系统设置「键盘 → 输入法 → 添加」的候选列表里没有业火。鼠须管同样装到 `/Library/Input Methods`，可以出现在该列表中。业火一旦被启用，输入本身正常。

## 排查

对比业火输入法与鼠须管的安装流程。

安装包的 `postinstall` 以 root 运行。业火用 `sudo -u <登录用户>` 启动 `Fire --install`。鼠须管把 `TISRegisterInputSource` 留在 `postinstall` 自己的进程里，启用和选中才切到登录用户（`scripts/postinstall`，提交 `d45b9a6`）。

业火的 `--install` 在 `AppDelegate.applicationDidFinishLaunching` 里处理。`@main` 放在 `AppDelegate` 上时，入口会先进入 `NSApplicationMain`。这条路径只调用 `TISRegisterInputSource`、`TISEnableInputSource`、`TISSelectInputSource`，然后返回；`Fire.shared` 等单例不会初始化。选中重试使用 `Timer`，依赖已经在跑的 AppKit RunLoop。

`Info.plist` 里输入模式的 `TISInputSourceID` 与 bundle ID 同为 `com.qwertyyb.inputmethod.Fire`。`TextInputSources.h` 要求模式 ID 是父 ID 加后缀。鼠须管、简体中文自带输入法都按这个写。

## 结论

候选列表不刷新，是因为注册发生在安装器的 Mach bootstrap 里，没有进入系统设置所在的图形会话。`sudo -u` 只改 uid，不改变这个 bootstrap。`TISRegisterInputSource` 的文档职责是让安装器重建输入源缓存（`TextInputSources.h`）。文档没有要求调用者必须是 root，也没有要求避开 AppKit。

下面几条不能当成「装完立刻出现」的保证：

- 苹果 DTS（[论坛帖 775526](https://developer.apple.com/forums/thread/775526)，2025）：近年系统上，`/Library/Input Methods` 的新输入源要注销再登录，系统设置才会重新读取。
- 鼠须管安装包 `onConclusion="RequireLogout"`。[issue 1132](https://github.com/rime/squirrel/issues/1132) 写明首次安装后重新登录仍需手动添加，有的机器要重启才看得到。
- [rimes 的 postinstall](https://github.com/scholay/rimes/blob/9dbc258a/scripts/pkg/scripts/postinstall)：TIS 写入只在 Aqua 会话生效；普通 `sudo -u` 下父输入法可能启用，可选模式没有。他们用 `launchctl asuser` 进入图形会话。

模式 ID 与 bundle ID 相同不符合上述头文件，但解释不了「当时不在列表里」。同一 ID 启用后可以正常输入；若系统因此拒绝列出，之后也不会出现。

## 后续方案

以下三项已落地。

1. 把 `@main` 挪到独立类型的 `static func main()`。`--install` 在调用 `NSApplicationMain` 之前处理并返回。该分支只做 `TISRegisterInputSource`，不创建 `NSApplication`。正常启动仍走 `NSApplicationMain`，`MainMenu.xib` 和 `AppDelegate` 保持不变。
2. `postinstall` 在自身进程中调用注册；启用和选中再用登录用户执行。若仍须在同一次进程里等待模式变得可选，用 `Thread.sleep` 循环重试查找、启用、选中。`Timer` 和 `NSApp` 在 `NSApplication` 起来之前不会工作。`launchctl asuser` 是把调用送进图形会话的另一种做法。系统设置仍可能要到注销登录后才更新。
3. Bundle ID 保持 `com.qwertyyb.inputmethod.Fire`。顶层 `TISInputSourceID` 用 bundle ID；模式 ID 改为 `com.qwertyyb.inputmethod.Fire.Hans`（`tsInputModeListKey`、`tsVisibleInputModeOrderedArrayKey`、`InputSource.kSourceID`、两份 `InfoPlist.strings` 一起改）。安装包标识、连接名、词库和偏好路径不动。已安装的机器要再添加一次新模式。
