![业火五笔输入法](https://github.com/qwertyyb/Fire/blob/ee8546aad395e4e6b3b1b756cfbd4f908c5dfe89/Fire/Assets.xcassets/AppIcon.appiconset/icon-256.png)
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fqwertyyb%2FFire.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Fqwertyyb%2FFire?ref=badge_shield)

# 业火五笔输入法
![](https://github.com/qwertyyb/FireWubi/workflows/CI/badge.svg)
![swift](https://img.shields.io/badge/swift-green.svg)
[![codebeat badge](https://codebeat.co/badges/f15efd85-e85d-4f72-87ab-f204abd17412)](https://codebeat.co/projects/github-com-qwertyyb-fire-master)
![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/qwertyyb/Fire?include_prereleases)

## 介绍

轻量干净，但功能强大的五笔输入法

## 截图

<img width="529" alt="image" src="https://user-images.githubusercontent.com/9018466/181672239-826e2f48-ce58-434a-9e05-6c58fcb8a5c8.png">

<img width="549" alt="image" src="https://user-images.githubusercontent.com/9018466/181672303-345e30f9-dfa6-4562-828f-6e5e8d87166a.png">

<img width="545" alt="image" src="https://user-images.githubusercontent.com/9018466/181672403-f5372465-ccc5-4b7b-befb-47c913278d8b.png">

<img width="557" alt="image" src="https://user-images.githubusercontent.com/9018466/181672445-0b8c2e1f-2105-4629-8b62-fe46001ebcec.png">

<img width="556" alt="image" src="https://user-images.githubusercontent.com/9018466/181672510-8827fead-7a39-450a-bf62-4a129c9dc82d.png">

<img width="540" alt="image" src="https://user-images.githubusercontent.com/9018466/181672573-9645e5fc-0092-4ff6-8b88-cd8e77d78453.png">

<img width="540" alt="image" src="https://user-images.githubusercontent.com/9018466/181672627-4ab5b3c4-6d22-4bdc-93e5-a80570c24ef1.png">



## 功能
1. 五笔输入(支持86版/98版/自定义编码方案)
2. 五笔拼音混输，支持编码提示
3. 纯拼音输入
3. -/+/向上/向下键支持翻页
4. z键查询
5. 候选词横向/竖向排列支持
6. 候选词数量可配置
7. 候选窗口显示输入编码
8. 应用输入模式切换
9. 支持手动调整候选词顺序(`control` + `数字`)
10. 支持用户词库
11. 支持自定义符号
12. 支持自定义主题
13. 支持数据统计
14. 支持临时英文模式(在中文输入模式下，按;键可以开启临时英文模式，输入英文字符和半角符号)
15. 命令行

## 命令行使用

```bash
# 输出当前输入模式
/Library/Input\ Methods/Fire.app/Contents/MacOS/Fire --get-mode

# 设置输入模式并显示提示
/Library/Input\ Methods/Fire.app/Contents/MacOS/Fire --set-mode enUS 或 zhhans

# 设置输入模式不显示提示
/Library/Input\ Methods/Fire.app/Contents/MacOS/Fire --set-mode enUS 或 zhhans false
```

## 安装
> [下载地址](https://github.com/qwertyyb/Fire/releases)

1. 下载 `FireInstall.pkg` 文件到本地

2. 点击安装后使用


## 安装遇到问题
1. 没有自动切换到该输入法。
    > 可以在设置->键盘->输入法中添加此输入法

2. 输入法中没有此输入法。
    > 重启设备即可


## 开发
```bash
# 下载项目到本地
git clone --recursive https://github.com/qwertyyb/Fire.git

# 构建 sqlcipher
./scripts/0_prepare_sqlcipher.sh

# 使用Xcode打开项目启动开发
open Fire.xcodeproj

# 由于调试时，APP运行目录在/Library/Input Methods, 所以需要添加权限
sudo chmod -R 777 /Library/Input Methods
```


## License
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fqwertyyb%2FFire.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fqwertyyb%2FFire?ref=badge_large)