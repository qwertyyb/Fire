//
//  CelebrationEffect.swift
//  Fire
//
//  Created by Reasonix on 2025/7/9.
//  Copyright © 2025 qwertyyb. All rights reserved.
//

import Cocoa
import QuartzCore

// MARK: - 庆祝动画粒子系统
//
// 中文上屏时触发粒子庆祝效果，支持 10 种不同粒子类型。
// 采用数据驱动设计：ParticleConfig 定义所有可变参数，
// 每种效果只需提供配置文件，无需重复实现 setup 逻辑。

// MARK: - 效果协议

protocol CelebrationEffect {
    /// 窗口水平偏移量（相对光标位置）
    var xOffset: CGFloat { get }
    /// 窗口垂直偏移量（相对光标位置）
    var yOffset: CGFloat { get }
    /// 粒子窗口大小
    var overlaySize: NSSize { get }
    /// 在 contentView 的 layer 上设置粒子发射器
    func setup(on contentView: NSView)
}

// MARK: - 入口

enum CelebrationOverlay {
    private static var windows: [NSPanel] = []

    static func showFlowers(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.flower) }
    static func showStars(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.star) }
    static func showBalloons(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.balloon) }
    static func showBubbles(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.bubble) }
    static func showFireBlast(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.fireBlast) }
    static func showHearts(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.heart) }
    static func showButterflies(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.butterfly) }
    static func showNotes(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.note) }
    static func showPaper(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.paper) }
    static func showEgg(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ParticleEffect.egg) }

    /// 创建 NSPanel → 挂载 effect → 淡入 → 延时 → 淡出 → 释放
    private static func show(at cursorPoint: NSPoint, effect: CelebrationEffect) {
        let overlaySize = effect.overlaySize
        let overlayRect = NSRect(origin: .zero, size: overlaySize)
        let win = makeWindow(overlayRect: overlayRect, at: cursorPoint, xOffset: effect.xOffset, yOffset: effect.yOffset)
        guard let contentView = win.contentView else { return }
        contentView.wantsLayer = true
        effect.setup(on: contentView)
        finalize(win: win)
    }

    /// 创建无边框透明 NSPanel，定位到光标附近
    private static func makeWindow(overlayRect: NSRect, at cursorPoint: NSPoint, xOffset: CGFloat, yOffset: CGFloat) -> NSPanel {
        let win = NSPanel(
            contentRect: overlayRect,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        win.isFloatingPanel = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .screenSaver
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false
        win.worksWhenModal = true
        let topLeft = NSPoint(x: cursorPoint.x - overlayRect.width / 2 + xOffset, y: cursorPoint.y + yOffset)
        win.setFrameTopLeftPoint(topLeft)
        return win
    }

    /// 淡入 → 0.2s 静置 → 淡出 → 从 windows 数组移除
    /// windows 数组限制最多 5 个实例，防止快速输入时窗口堆积
    private static func finalize(win: NSPanel) {
        guard win.contentView?.layer != nil else { return }
        if windows.count >= 5 { windows.removeFirst().orderOut(nil) }
        windows.append(win)
        win.alphaValue = 0
        win.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            win.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak win] in
            guard let win = win else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                win.animator().alphaValue = 0
            } completionHandler: {
                win.orderOut(nil)
                windows.removeAll { $0 === win }
            }
        }
    }
}

// MARK: - CelebrationEffectType 扩展

extension CelebrationEffectType {
    func show(at cursorPoint: NSPoint) {
        switch self {
        case .none: break
        case .flowers: CelebrationOverlay.showFlowers(at: cursorPoint)
        case .stars: CelebrationOverlay.showStars(at: cursorPoint)
        case .balloons: CelebrationOverlay.showBalloons(at: cursorPoint)
        case .bubbles: CelebrationOverlay.showBubbles(at: cursorPoint)
        case .fireBlast: CelebrationOverlay.showFireBlast(at: cursorPoint)
        case .hearts: CelebrationOverlay.showHearts(at: cursorPoint)
        case .butterflies: CelebrationOverlay.showButterflies(at: cursorPoint)
        case .notes: CelebrationOverlay.showNotes(at: cursorPoint)
        case .paper: CelebrationOverlay.showPaper(at: cursorPoint)
        case .egg: CelebrationOverlay.showEgg(at: cursorPoint)
        }
    }
}

// MARK: - 粒子配置

/// 粒子效果的全部可变参数，每种效果提供一个配置实例
struct ParticleConfig {
    // 图像和颜色
    let image: CGImage
    let colors: [NSColor]

    // 窗口定位
    let overlaySize: NSSize
    let xOffset: CGFloat
    let yOffset: CGFloat

    // 发射器布局（默认居中点发射）
    var emitterPositionRatio: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var emitterSizeRatio: CGSize = .zero
    var emitterShape: CAEmitterLayerEmitterShape = .point
    var renderMode: CAEmitterLayerRenderMode = .additive
    var masksToBounds: Bool = true

    // 粒子数量和生命周期
    var cellCount: ClosedRange<Int> = 3...5
    var birthRate: ClosedRange<Float> = 1...3
    var lifetime: ClosedRange<Float> = 0.5...2.0
    var lifetimeRange: Float = 0.3

    // 运动参数
    var velocity: ClosedRange<CGFloat> = 60...200
    var velocityRange: CGFloat = 50
    var yAcceleration: CGFloat = -20     // 负值向上
    var xAcceleration: ClosedRange<CGFloat> = -20...20
    var emissionLongitude: CGFloat = .pi * 2
    var emissionRange: CGFloat = .pi * 2

    // 旋转
    var spin: ClosedRange<CGFloat> = 0...(.pi * 2)
    var spinRange: CGFloat = .pi * 2

    // 缩放
    var scale: ClosedRange<CGFloat> = 0.03...0.3
    var scaleRange: CGFloat = 0.1
    var scaleSpeed: CGFloat = 0

    // 淡出
    var alphaSpeed: Float = -0.3
    var alphaRange: Float = 0.3
}

// MARK: - 统一粒子效果

/// 通用粒子效果实现，通过不同 ParticleConfig 实例化出不同视觉效果
private struct ParticleEffect: CelebrationEffect {
    let config: ParticleConfig

    var xOffset: CGFloat { config.xOffset }
    var yOffset: CGFloat { config.yOffset }
    var overlaySize: NSSize { config.overlaySize }

    func setup(on contentView: NSView) {
        if !config.masksToBounds, let layer = contentView.layer {
            layer.masksToBounds = false
        }

        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(
            x: config.overlaySize.width * config.emitterPositionRatio.x,
            y: config.overlaySize.height * config.emitterPositionRatio.y
        )
        em.emitterShape = config.emitterShape
        em.renderMode = config.renderMode
        em.masksToBounds = false

        if config.emitterSizeRatio != .zero {
            em.emitterSize = CGSize(
                width: config.overlaySize.width * config.emitterSizeRatio.width,
                height: config.overlaySize.height * config.emitterSizeRatio.height
            )
        }

        let colorCount = Int.random(in: config.cellCount)
        em.emitterCells = config.colors.shuffled().prefix(colorCount).map { color in
            let cell = CAEmitterCell()
            cell.birthRate = .random(in: config.birthRate)
            cell.lifetime = .random(in: config.lifetime)
            cell.lifetimeRange = config.lifetimeRange
            cell.velocity = .random(in: config.velocity)
            cell.velocityRange = config.velocityRange
            cell.yAcceleration = config.yAcceleration
            cell.xAcceleration = .random(in: config.xAcceleration)
            cell.emissionLongitude = config.emissionLongitude
            cell.emissionRange = config.emissionRange
            cell.spin = .random(in: config.spin)
            cell.spinRange = config.spinRange
            cell.scale = .random(in: config.scale)
            cell.scaleRange = config.scaleRange
            cell.scaleSpeed = config.scaleSpeed
            cell.alphaSpeed = config.alphaSpeed
            cell.alphaRange = config.alphaRange
            cell.color = color.cgColor
            cell.contents = config.image
            return cell
        }
        contentView.layer?.addSublayer(em)
    }
}

// MARK: - 效果定义

private extension ParticleEffect {
    /// 鲜花：粉色系花瓣向四周缓慢飘散
    static let flower = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.petal(size: 20),
        colors: [
            NSColor(red: 1, green: 0.3, blue: 0.4, alpha: 0.55),
            NSColor(red: 1, green: 0.5, blue: 0.7, alpha: 0.5),
            NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.5),
            NSColor(red: 0.9, green: 0.4, blue: 1, alpha: 0.45),
            NSColor(red: 1, green: 0.65, blue: 0.4, alpha: 0.5)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 280,
        birthRate: 0.25...0.5,
        lifetime: 2.0...2.5,
        lifetimeRange: 0.5,
        velocity: 60...120,
        velocityRange: 50,
        yAcceleration: -20,
        spin: .pi * 2 ... .pi * 2,
        scale: 0.03...0.05,
        scaleRange: 0.02,
        scaleSpeed: 3
    ))

    /// 星星：高亮度彩色星芒四射
    static let star = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.star(size: 28),
        colors: [
            NSColor(red: 1, green: 0.6, blue: 0.0, alpha: 1),
            NSColor(red: 1, green: 0.9, blue: 0.0, alpha: 1),
            NSColor(red: 1, green: 0.3, blue: 0.0, alpha: 1),
            NSColor(red: 0.0, green: 0.5, blue: 1, alpha: 1),
            NSColor(red: 1, green: 0.0, blue: 0.4, alpha: 1)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 280,
        birthRate: 5...8,
        lifetime: 0.4...0.55,
        lifetimeRange: 0.15,
        velocity: 150...350,
        velocityRange: 120,
        yAcceleration: 0,
        xAcceleration: -20...20,
        spin: .pi * 3 ... .pi * 3,
        spinRange: .pi * 4,
        scale: 0.05...0.08,
        scaleRange: 0.03,
        scaleSpeed: 1.5,
        alphaSpeed: -2,
        alphaRange: 0.5
    ))

    /// 气球：从底部线状发射，缓慢飘升
    static let balloon = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.balloon(size: 144),
        colors: [
            NSColor(red: 1, green: 0.3, blue: 0.35, alpha: 0.9),
            NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.9),
            NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.9),
            NSColor(red: 1, green: 0.4, blue: 0.8, alpha: 0.85),
            NSColor(red: 0.8, green: 0.4, blue: 1, alpha: 0.85)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 510,
        emitterPositionRatio: CGPoint(x: 0.5, y: 0.16),
        emitterSizeRatio: CGSize(width: 0.8, height: 0),
        emitterShape: .line,
        cellCount: 3...6,
        birthRate: 1...2,
        lifetime: 1.0...1.3,
        lifetimeRange: 0.3,
        velocity: 120...200,
        velocityRange: 60,
        yAcceleration: -100,
        xAcceleration: -30...30,
        emissionLongitude: -.pi / 2,
        emissionRange: .pi / 6,
        spin: -0.5...0.5,
        spinRange: 1,
        scale: 0.3...0.4,
        scaleRange: 0.1,
        alphaSpeed: -0.6,
        alphaRange: 0.2
    ))

    /// 泡泡：从顶部线状发射，轻盈上升
    static let bubble = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.bubble(size: 80),
        colors: [
            NSColor(red: 0.5, green: 0.8, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.6, blue: 0.8, alpha: 0.88),
            NSColor(red: 0.7, green: 1, blue: 0.7, alpha: 0.85),
            NSColor(red: 0.8, green: 0.6, blue: 1, alpha: 0.85),
            NSColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.88)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 150,
        emitterPositionRatio: CGPoint(x: 0.5, y: 0.8),
        emitterSizeRatio: CGSize(width: 0.5, height: 0),
        emitterShape: .line,
        masksToBounds: false,
        birthRate: 0.5...1.5,
        lifetime: 1.2...1.5,
        lifetimeRange: 0.3,
        velocity: 80...150,
        velocityRange: 50,
        yAcceleration: -60,
        xAcceleration: -20...20,
        emissionLongitude: -.pi / 2,
        emissionRange: .pi / 5,
        spin: -0.3...0.3,
        spinRange: 0.5,
        scale: 0.4...0.55,
        scaleRange: 0.15,
        scaleSpeed: 0.3,
        alphaSpeed: -0.5,
        alphaRange: 0.2
    ))

    /// 喷火：从底部线状向上喷射火焰
    static let fireBlast = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.fireBlast(size: 10),
        colors: [
            NSColor(red: 1, green: 0.3, blue: 0.4, alpha: 0.9),
            NSColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.9),
            NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.9),
            NSColor(red: 1, green: 0.5, blue: 0.8, alpha: 0.85),
            NSColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.9)
        ],
        overlaySize: NSSize(width: 400, height: 700),
        xOffset: 80, yOffset: 600,
        emitterPositionRatio: CGPoint(x: 0.5, y: 0.15),
        emitterSizeRatio: CGSize(width: 0.3, height: 0),
        emitterShape: .line,
        masksToBounds: false,
        cellCount: 4...6,
        birthRate: 60...75,
        lifetime: 0.8...1.1,
        lifetimeRange: 0.3,
        velocity: 60...120,
        velocityRange: 40,
        yAcceleration: 30,
        xAcceleration: -4...4,
        emissionLongitude: .pi / 2,
        emissionRange: .pi / 12,
        spin: .pi * 4 ... .pi * 4,
        spinRange: .pi * 4,
        scale: 0.8...1.1,
        scaleRange: 0.3,
        alphaSpeed: -0.8,
        alphaRange: 0.2
    ))

    /// 爱心：粉色爱心向四周缓慢飘散
    static let heart = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.heart(size: 24),
        colors: [
            NSColor(red: 1, green: 0.3, blue: 0.4, alpha: 0.55),
            NSColor(red: 1, green: 0.5, blue: 0.7, alpha: 0.5),
            NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.5),
            NSColor(red: 0.9, green: 0.4, blue: 1, alpha: 0.45),
            NSColor(red: 1, green: 0.65, blue: 0.4, alpha: 0.5)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 280,
        birthRate: 0.25...0.5,
        lifetime: 2.0...2.5,
        lifetimeRange: 0.5,
        velocity: 60...120,
        velocityRange: 50,
        yAcceleration: -20,
        spin: .pi * 2 ... .pi * 2,
        scale: 0.03...0.05,
        scaleRange: 0.02,
        scaleSpeed: 3
    ))

    /// 蝴蝶：彩色蝴蝶向四周飞散，不自旋
    static let butterfly = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.butterfly(size: 180),
        colors: [
            NSColor(red: 1, green: 0.5, blue: 0.7, alpha: 0.9),
            NSColor(red: 0.5, green: 0.7, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.85),
            NSColor(red: 0.8, green: 0.4, blue: 1, alpha: 0.85),
            NSColor(red: 1, green: 0.6, blue: 0.3, alpha: 0.9)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 280,
        birthRate: 0.5...0.75,
        lifetime: 0.6...0.8,
        lifetimeRange: 0.2,
        velocity: 80...180,
        velocityRange: 70,
        yAcceleration: -40,
        xAcceleration: -30...30,
        spin: 0...0,
        spinRange: 0,
        scale: 0.02...0.03,
        scaleRange: 0.01,
        scaleSpeed: 0.8,
        alphaSpeed: -1,
        alphaRange: 0.3
    ))

    /// 音符：彩色音符向四周飞散，不自旋
    static let note = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.note(size: 200),
        colors: [
            NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.3, blue: 0.5, alpha: 0.85),
            NSColor(red: 0.8, green: 0.4, blue: 1, alpha: 0.85),
            NSColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.85),
            NSColor(red: 0.3, green: 0.9, blue: 0.6, alpha: 0.85)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 280,
        birthRate: 1.6...2.8,
        lifetime: 0.5...0.65,
        lifetimeRange: 0.15,
        velocity: 100...220,
        velocityRange: 80,
        yAcceleration: -50,
        xAcceleration: -20...20,
        spin: 0...0,
        spinRange: 0,
        scale: 0.01...0.015,
        scaleRange: 0.005,
        scaleSpeed: 0.6,
        alphaSpeed: -1.5,
        alphaRange: 0.3
    ))

    /// 彩纸：彩色纸片急速四散
    static let paper = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.paper(size: 16),
        colors: [
            NSColor(red: 1, green: 0.0, blue: 0.0, alpha: 1),
            NSColor(red: 0.0, green: 0.4, blue: 1, alpha: 1),
            NSColor(red: 1, green: 0.9, blue: 0.0, alpha: 1),
            NSColor(red: 0.0, green: 1, blue: 0.15, alpha: 1),
            NSColor(red: 1, green: 0.0, blue: 0.5, alpha: 1)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 280,
        birthRate: 10...18,
        lifetime: 0.5...0.65,
        lifetimeRange: 0.15,
        velocity: 120...250,
        velocityRange: 90,
        yAcceleration: -20,
        xAcceleration: -30...30,
        spin: .pi * 4 ... .pi * 4,
        spinRange: .pi * 4,
        scale: 0.3...0.42,
        scaleRange: 0.12,
        alphaSpeed: -1.5,
        alphaRange: 0.3
    ))

    /// 鸡蛋：从底部线状发射，带弹跳感
    static let egg = ParticleEffect(config: ParticleConfig(
        image: ImageHelper.egg(size: 200),
        colors: [
            NSColor(red: 1, green: 0.85, blue: 0.7, alpha: 0.9),
            NSColor(red: 0.95, green: 0.75, blue: 0.6, alpha: 0.85),
            NSColor(red: 1, green: 0.9, blue: 0.8, alpha: 0.85),
            NSColor(red: 0.9, green: 0.7, blue: 0.5, alpha: 0.8)
        ],
        overlaySize: NSSize(width: 500, height: 500),
        xOffset: 20, yOffset: 510,
        emitterPositionRatio: CGPoint(x: 0.5, y: 0.16),
        emitterSizeRatio: CGSize(width: 0.8, height: 0),
        emitterShape: .line,
        cellCount: 2...4,
        birthRate: 1...2,
        lifetime: 1.0...1.3,
        lifetimeRange: 0.3,
        velocity: 120...200,
        velocityRange: 60,
        yAcceleration: -100,
        xAcceleration: -30...30,
        emissionLongitude: -.pi / 2,
        emissionRange: .pi / 6,
        spin: -0.5...0.5,
        spinRange: 1,
        scale: 0.3...0.4,
        scaleRange: 0.1,
        alphaSpeed: -0.6,
        alphaRange: 0.2
    ))
}

// MARK: - 粒子图像生成

/// 程序化生成粒子纹理（均为白色，运行时由 CAEmitterCell.color 染色）
private enum ImageHelper {
    /// 五瓣桃花形状
    static func petal(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        let pr = size * 0.22
        let po = size * 0.16
        for i in 0..<5 {
            ctx.saveGState()
            ctx.translateBy(x: size / 2, y: size / 2)
            ctx.rotate(by: CGFloat(i) * .pi * 2 / 5)
            ctx.fillEllipse(in: CGRect(x: -pr + po, y: -pr, width: pr * 2, height: pr * 2))
            ctx.restoreGState()
        }
        return ctx.makeImage()!
    }

    /// 四角星（两个旋转 45° 的椭圆合并）
    static func star(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        let c = CGPoint(x: size / 2, y: size / 2); let hw = size * 0.08; let hh = size * 0.45
        ctx.fillEllipse(in: CGRect(x: c.x - hw, y: c.y - hh, width: hw * 2, height: hh * 2))
        ctx.fillEllipse(in: CGRect(x: c.x - hh, y: c.y - hw, width: hh * 2, height: hw * 2))
        ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: .pi / 4)
        ctx.fillEllipse(in: CGRect(x: -hw, y: -hh, width: hw * 2, height: hh * 2))
        ctx.fillEllipse(in: CGRect(x: -hh, y: -hw, width: hh * 2, height: hw * 2))
        ctx.restoreGState(); return ctx.makeImage()!
    }

    /// 气球（圆形主体 + 底部打结 + 绳子）
    static func balloon(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: size * 0.2, y: size * 0.4, width: size * 0.6, height: size * 0.6))
        let tx = size / 2; let knotY = size * 0.37
        ctx.move(to: CGPoint(x: tx - size * 0.05, y: knotY + size * 0.03))
        ctx.addLine(to: CGPoint(x: tx + size * 0.05, y: knotY + size * 0.03))
        ctx.addLine(to: CGPoint(x: tx, y: knotY)); ctx.closePath(); ctx.fillPath()
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: tx, y: knotY))
        ctx.addLine(to: CGPoint(x: tx - size * 0.03, y: size * 0.04))
        ctx.strokePath()
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    /// 鸡蛋（椭圆 + 纵向拉伸）
    static func egg(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
        ctx.saveGState()
        ctx.translateBy(x: size / 2, y: size / 2)
        ctx.scaleBy(x: 1, y: 1.3)
        ctx.addEllipse(in: CGRect(x: -size * 0.28, y: -size * 0.28, width: size * 0.56, height: size * 0.56))
        ctx.fillPath()
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    /// 半透明气泡（圆环 + 高光）
    static func bubble(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        ctx.fillEllipse(in: CGRect(x: 3, y: 3, width: size - 6, height: size - 6))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: CGRect(x: size * 0.22, y: size * 0.56, width: size * 0.2, height: size * 0.1))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor); ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: 3, y: 3, width: size - 6, height: size - 6))
        return ctx.makeImage()!
    }

    /// 火焰粒子（细长矩形）
    static func fireBlast(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 1, y: size * 0.2, width: size - 2, height: size * 0.6))
        return ctx.makeImage()!
    }

    /// 爱心（使用贝塞尔曲线绘制）
    static func heart(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        let s = size; let cx = s / 2
        ctx.move(to: CGPoint(x: cx, y: s * 0.88))
        ctx.addCurve(to: CGPoint(x: s * 0.78, y: s * 0.22),
            control1: CGPoint(x: s * 0.95, y: s * 0.62),
            control2: CGPoint(x: s * 0.92, y: s * 0.28))
        ctx.addCurve(to: CGPoint(x: cx, y: s * 0.26),
            control1: CGPoint(x: s * 0.68, y: s * 0.16),
            control2: CGPoint(x: s * 0.55, y: s * 0.26))
        ctx.addCurve(to: CGPoint(x: s * 0.22, y: s * 0.22),
            control1: CGPoint(x: s * 0.45, y: s * 0.26),
            control2: CGPoint(x: s * 0.32, y: s * 0.16))
        ctx.addCurve(to: CGPoint(x: cx, y: s * 0.88),
            control1: CGPoint(x: s * 0.08, y: s * 0.28),
            control2: CGPoint(x: s * 0.05, y: s * 0.62))
        ctx.fillPath()
        return ctx.makeImage()!
    }

    /// 蝴蝶（前翅 + 后翅 + 身体 + 触角）
    static func butterfly(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        let s = size; let cx = s / 2
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cx)
        ctx.rotate(by: .pi)
        ctx.translateBy(x: -cx, y: -cx)
        ctx.fillEllipse(in: CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.38, height: s * 0.25))
        ctx.fillEllipse(in: CGRect(x: s * 0.54, y: s * 0.08, width: s * 0.38, height: s * 0.25))
        ctx.fillEllipse(in: CGRect(x: s * 0.14, y: s * 0.28, width: s * 0.26, height: s * 0.28))
        ctx.fillEllipse(in: CGRect(x: s * 0.6, y: s * 0.28, width: s * 0.26, height: s * 0.28))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - s * 0.025, y: s * 0.18, width: s * 0.05, height: s * 0.45))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: cx, y: s * 0.18))
        ctx.addLine(to: CGPoint(x: cx - s * 0.08, y: s * 0.03))
        ctx.move(to: CGPoint(x: cx, y: s * 0.18))
        ctx.addLine(to: CGPoint(x: cx + s * 0.08, y: s * 0.03))
        ctx.strokePath()
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    /// 音符（椭圆头 + 符干 + 符尾弧线）
    static func note(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: size * 0.15, y: size * 0.1, width: size * 0.45, height: size * 0.35))
        ctx.fill(CGRect(x: size * 0.5, y: size * 0.3, width: size * 0.08, height: size * 0.65))
        ctx.saveGState(); ctx.translateBy(x: size * 0.54, y: size * 0.85)
        ctx.rotate(by: -0.2)
        ctx.fillEllipse(in: CGRect(x: 0, y: -size * 0.06, width: size * 0.25, height: size * 0.12))
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    /// 彩纸碎片（矩形纸片）
    static func paper(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: size * 0.15, y: 0, width: size * 0.7, height: size))
        return ctx.makeImage()!
    }
}
