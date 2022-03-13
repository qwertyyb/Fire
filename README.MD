![业火五笔输入法](https://ftp.bmp.ovh/imgs/2020/10/f6411ae11c113c3f.png)

# 业火五笔输入法
![](https://github.com/qwertyyb/FireWubi/workflows/CI/badge.svg)
![swift](https://img.shields.io/badge/swift-green.svg)
[![codebeat badge](https://codebeat.co/badges/f15efd85-e85d-4f72-87ab-f204abd17412)](https://codebeat.co/projects/github-com-qwertyyb-fire-master)

## 介绍
使用 `swift` 基于 `InputMethodKit` 实现的Mac平台五笔输入法, `InputMethodKit` 真是巨坑

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
git clone https://github.com/qwertyyb/Fire.git

# 安装依赖
pod install

# 使用Xcode打开项目启动开发
```
