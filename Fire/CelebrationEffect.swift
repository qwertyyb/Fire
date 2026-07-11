//
//  CelebrationEffect.swift
//  Fire
//
//  Created by Reasonix on 2025/7/9.
//  Copyright © 2025 qwertyyb. All rights reserved.
//

import Cocoa
import QuartzCore

// MARK: - 效果协议

protocol CelebrationEffect {
    var xOffset: CGFloat { get }
    var yOffset: CGFloat { get }
    var overlaySize: NSSize { get }
    func setup(on contentView: NSView)
}

// MARK: - 入口

enum CelebrationOverlay {
    private static var windows: [NSPanel] = []

    static func showFlowers(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: FlowerEffect()) }
    static func showStars(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: StarEffect()) }
    static func showBalloons(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: BalloonEffect()) }
    static func showBubbles(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: BubbleEffect()) }
    static func showFireBlast(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: FireBlastEffect()) }
    static func showHearts(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: HeartEffect()) }
    static func showButterflies(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: ButterflyEffect()) }
    static func showNotes(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: NoteEffect()) }
    static func showPaper(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: PaperEffect()) }
    static func showEgg(at cursorPoint: NSPoint) { show(at: cursorPoint, effect: EggEffect()) }

    private static func show(at cursorPoint: NSPoint, effect: CelebrationEffect) {
        let overlaySize = effect.overlaySize
        let overlayRect = NSRect(origin: .zero, size: overlaySize)
        let win = makeWindow(overlayRect: overlayRect, at: cursorPoint, xOffset: effect.xOffset, yOffset: effect.yOffset)
        guard let contentView = win.contentView else { return }
        contentView.wantsLayer = true
        effect.setup(on: contentView)
        finalize(win: win)
    }

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

// MARK: - 鲜花

private struct FlowerEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 280
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.petal(size: 20)
        let cs = [NSColor(red: 1, green: 0.3, blue: 0.4, alpha: 0.55),
            NSColor(red: 1, green: 0.5, blue: 0.7, alpha: 0.5),
            NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.5),
            NSColor(red: 0.9, green: 0.4, blue: 1, alpha: 0.45),
            NSColor(red: 1, green: 0.65, blue: 0.4, alpha: 0.5)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        em.emitterShape = .point; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float.random(in: 0.25...0.5); cell.lifetime = 2.0; cell.lifetimeRange = 0.5
            cell.velocity = CGFloat(Int.random(in: 60...120)); cell.velocityRange = 50; cell.yAcceleration = -20
            cell.emissionLongitude = .pi * 2; cell.emissionRange = .pi * 2; cell.spin = .pi * 2; cell.spinRange = .pi * 2
            cell.scale = 0.03; cell.scaleRange = 0.02; cell.scaleSpeed = 3.0; cell.alphaSpeed = -0.3; cell.alphaRange = 0.3
            cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 星星

private struct StarEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 280
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.star(size: 28)
        let cs = [NSColor(red: 1, green: 0.6, blue: 0.0, alpha: 1),
            NSColor(red: 1, green: 0.9, blue: 0.0, alpha: 1),
            NSColor(red: 1, green: 0.3, blue: 0.0, alpha: 1),
            NSColor(red: 0.0, green: 0.5, blue: 1, alpha: 1),
            NSColor(red: 1, green: 0.0, blue: 0.4, alpha: 1)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        em.emitterShape = .point; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float(Int.random(in: 5...8)); cell.lifetime = 0.4; cell.lifetimeRange = 0.15
            cell.velocity = CGFloat(Int.random(in: 150...350)); cell.velocityRange = 120
            cell.yAcceleration = CGFloat.random(in: -20...20); cell.xAcceleration = CGFloat.random(in: -20...20)
            cell.emissionLongitude = .pi * 2; cell.emissionRange = .pi * 2; cell.spin = .pi * 3; cell.spinRange = .pi * 4
            cell.scale = 0.05; cell.scaleRange = 0.03; cell.scaleSpeed = 1.5; cell.alphaSpeed = -2.0; cell.alphaRange = 0.5
            cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 气球

private struct BalloonEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 510
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.balloon(size: 144)
        let cs = [NSColor(red: 1, green: 0.3, blue: 0.35, alpha: 0.9),
            NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.9),
            NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.9),
            NSColor(red: 1, green: 0.4, blue: 0.8, alpha: 0.85),
            NSColor(red: 0.8, green: 0.4, blue: 1, alpha: 0.85)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: 80)
        em.emitterSize = CGSize(width: overlaySize.width * 0.8, height: 0); em.emitterShape = .line; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...6)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float(Int.random(in: 1...2)); cell.lifetime = 1.0; cell.lifetimeRange = 0.3
            cell.velocity = CGFloat(Int.random(in: 120...200)); cell.velocityRange = 60; cell.yAcceleration = -100
            cell.xAcceleration = CGFloat.random(in: -30...30); cell.emissionLongitude = -.pi / 2; cell.emissionRange = .pi / 6
            cell.spin = CGFloat.random(in: -0.5...0.5); cell.spinRange = 1.0; cell.scale = 0.3; cell.scaleRange = 0.1
            cell.alphaSpeed = -0.6; cell.alphaRange = 0.2; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 泡泡

private struct BubbleEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 150
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.bubble(size: 80)
        let cs = [NSColor(red: 0.5, green: 0.8, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.6, blue: 0.8, alpha: 0.88),
            NSColor(red: 0.7, green: 1, blue: 0.7, alpha: 0.85),
            NSColor(red: 0.8, green: 0.6, blue: 1, alpha: 0.85),
            NSColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.88)]
        let em = CAEmitterLayer()
        if let layer = contentView.layer {
            layer.masksToBounds = false
        }
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height * 0.8)
        em.emitterSize = CGSize(width: overlaySize.width * 0.5, height: 0); em.emitterShape = .line; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float.random(in: 0.5...1.5); cell.lifetime = 1.2; cell.lifetimeRange = 0.3
            cell.velocity = CGFloat(Int.random(in: 80...150)); cell.velocityRange = 50; cell.yAcceleration = -60
            cell.xAcceleration = CGFloat.random(in: -20...20); cell.emissionLongitude = -.pi / 2; cell.emissionRange = .pi / 5
            cell.spin = CGFloat.random(in: -0.3...0.3); cell.spinRange = 0.5; cell.scale = 0.4; cell.scaleRange = 0.15
            cell.scaleSpeed = 0.3; cell.alphaSpeed = -0.5; cell.alphaRange = 0.2; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 喷火

private struct FireBlastEffect: CelebrationEffect {
    let xOffset: CGFloat = 80; let yOffset: CGFloat = 600
    let overlaySize: NSSize = NSSize(width: 400, height: 700)
    func setup(on contentView: NSView) {
        if let layer = contentView.layer {
            layer.masksToBounds = false
        }
        let img = ImageHelper.fireBlast(size: 10)
        let cs = [NSColor(red: 1, green: 0.3, blue: 0.4, alpha: 0.9),
            NSColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.9),
            NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.9),
            NSColor(red: 1, green: 0.5, blue: 0.8, alpha: 0.85),
            NSColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.9)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height * 0.15)
        em.emitterSize = CGSize(width: overlaySize.width * 0.3, height: 0); em.emitterShape = .line; em.renderMode = .additive
        em.masksToBounds = false
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 4...6)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float(Int.random(in: 60...75)); cell.lifetime = 0.8; cell.lifetimeRange = 0.3
            cell.velocity = CGFloat(Int.random(in: 60...120)); cell.velocityRange = 40; cell.yAcceleration = 30
            cell.xAcceleration = CGFloat.random(in: -4...4); cell.emissionLongitude = .pi / 2; cell.emissionRange = .pi / 12
            cell.spin = .pi * 4; cell.spinRange = .pi * 4; cell.scale = 0.8; cell.scaleRange = 0.3
            cell.alphaSpeed = -0.8; cell.alphaRange = 0.2; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 爱心

private struct HeartEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 280
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.heart(size: 24)
        let cs = [NSColor(red: 1, green: 0.3, blue: 0.4, alpha: 0.55),
            NSColor(red: 1, green: 0.5, blue: 0.7, alpha: 0.5),
            NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.5),
            NSColor(red: 0.9, green: 0.4, blue: 1, alpha: 0.45),
            NSColor(red: 1, green: 0.65, blue: 0.4, alpha: 0.5)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        em.emitterShape = .point; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float.random(in: 0.25...0.5); cell.lifetime = 2.0; cell.lifetimeRange = 0.5
            cell.velocity = CGFloat(Int.random(in: 60...120)); cell.velocityRange = 50; cell.yAcceleration = -20
            cell.emissionLongitude = .pi * 2; cell.emissionRange = .pi * 2; cell.spin = .pi * 2; cell.spinRange = .pi * 2
            cell.scale = 0.03; cell.scaleRange = 0.02; cell.scaleSpeed = 3.0; cell.alphaSpeed = -0.3; cell.alphaRange = 0.3
            cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 蝴蝶

private struct ButterflyEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 280
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.butterfly(size: 180)
        let cs = [NSColor(red: 1, green: 0.5, blue: 0.7, alpha: 0.9),
            NSColor(red: 0.5, green: 0.7, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.85),
            NSColor(red: 0.8, green: 0.4, blue: 1, alpha: 0.85),
            NSColor(red: 1, green: 0.6, blue: 0.3, alpha: 0.9)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        em.emitterShape = .point; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float.random(in: 0.5...0.75); cell.lifetime = 0.6; cell.lifetimeRange = 0.2
            cell.velocity = CGFloat(Int.random(in: 80...180)); cell.velocityRange = 70; cell.yAcceleration = -40
            cell.xAcceleration = CGFloat.random(in: -30...30); cell.emissionLongitude = .pi * 2; cell.emissionRange = .pi * 2
            cell.spin = 0; cell.spinRange = 0; cell.scale = 0.02; cell.scaleRange = 0.01
            cell.scaleSpeed = 0.8; cell.alphaSpeed = -1.0; cell.alphaRange = 0.3; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 音符

private struct NoteEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 280
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.note(size: 200)
        let cs = [NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.9),
            NSColor(red: 1, green: 0.3, blue: 0.5, alpha: 0.85),
            NSColor(red: 0.8, green: 0.4, blue: 1, alpha: 0.85),
            NSColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.85),
            NSColor(red: 0.3, green: 0.9, blue: 0.6, alpha: 0.85)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        em.emitterShape = .point; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float.random(in: 1.6...2.8); cell.lifetime = 0.5; cell.lifetimeRange = 0.15
            cell.velocity = CGFloat(Int.random(in: 100...220)); cell.velocityRange = 80; cell.yAcceleration = -50
            cell.xAcceleration = CGFloat.random(in: -20...20); cell.emissionLongitude = .pi * 2; cell.emissionRange = .pi * 2
            cell.spin = 0; cell.spinRange = 0; cell.scale = 0.01; cell.scaleRange = 0.005
            cell.scaleSpeed = 0.6; cell.alphaSpeed = -1.5; cell.alphaRange = 0.3; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 彩纸

private struct PaperEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 280
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.paper(size: 16)
        let cs = [NSColor(red: 1, green: 0.0, blue: 0.0, alpha: 1),
            NSColor(red: 0.0, green: 0.4, blue: 1, alpha: 1),
            NSColor(red: 1, green: 0.9, blue: 0.0, alpha: 1),
            NSColor(red: 0.0, green: 1, blue: 0.15, alpha: 1),
            NSColor(red: 1, green: 0.0, blue: 0.5, alpha: 1)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        em.emitterShape = .point; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 3...5)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float(Int.random(in: 10...18)); cell.lifetime = 0.5; cell.lifetimeRange = 0.15
            cell.velocity = CGFloat(Int.random(in: 120...250)); cell.velocityRange = 90; cell.yAcceleration = -20
            cell.xAcceleration = CGFloat.random(in: -30...30); cell.emissionLongitude = .pi * 2; cell.emissionRange = .pi * 2
            cell.spin = .pi * 4; cell.spinRange = .pi * 4; cell.scale = 0.3; cell.scaleRange = 0.12
            cell.alphaSpeed = -1.5; cell.alphaRange = 0.3; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 鸡蛋

private struct EggEffect: CelebrationEffect {
    let xOffset: CGFloat = 20; let yOffset: CGFloat = 510
    let overlaySize: NSSize = NSSize(width: 500, height: 500)
    func setup(on contentView: NSView) {
        let img = ImageHelper.egg(size: 200)
        let cs = [NSColor(red: 1, green: 0.85, blue: 0.7, alpha: 0.9),
            NSColor(red: 0.95, green: 0.75, blue: 0.6, alpha: 0.85),
            NSColor(red: 1, green: 0.9, blue: 0.8, alpha: 0.85),
            NSColor(red: 0.9, green: 0.7, blue: 0.5, alpha: 0.8)]
        let em = CAEmitterLayer()
        em.emitterPosition = CGPoint(x: overlaySize.width / 2, y: 80)
        em.emitterSize = CGSize(width: overlaySize.width * 0.8, height: 0); em.emitterShape = .line; em.renderMode = .additive
        var cells: [CAEmitterCell] = []
        for c in cs.shuffled().prefix(Int.random(in: 2...4)) {
            let cell = CAEmitterCell()
            cell.birthRate = Float(Int.random(in: 1...2)); cell.lifetime = 1.0; cell.lifetimeRange = 0.3
            cell.velocity = CGFloat(Int.random(in: 120...200)); cell.velocityRange = 60; cell.yAcceleration = -100
            cell.xAcceleration = CGFloat.random(in: -30...30); cell.emissionLongitude = -.pi / 2; cell.emissionRange = .pi / 6
            cell.spin = CGFloat.random(in: -0.5...0.5); cell.spinRange = 1.0; cell.scale = 0.3; cell.scaleRange = 0.1
            cell.alphaSpeed = -0.6; cell.alphaRange = 0.2; cell.color = c.cgColor; cell.contents = img
            cells.append(cell)
        }
        em.emitterCells = cells; contentView.layer?.addSublayer(em)
    }
}

// MARK: - 粒子图像生成

private enum ImageHelper {
    static func petal(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        // 五瓣桃花
        let pr = size * 0.22  // 花瓣半径
        let po = size * 0.16  // 花瓣偏移
        for i in 0..<5 {
            ctx.saveGState()
            ctx.translateBy(x: size / 2, y: size / 2)
            ctx.rotate(by: CGFloat(i) * .pi * 2 / 5)
            ctx.fillEllipse(in: CGRect(x: -pr + po, y: -pr, width: pr * 2, height: pr * 2))
            ctx.restoreGState()
        }
        return ctx.makeImage()!
    }

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

    static func balloon(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        // 气球圆形主体（上半部分，给绳子留空间）
        ctx.fillEllipse(in: CGRect(x: size * 0.2, y: size * 0.4, width: size * 0.6, height: size * 0.6))
        // 底部打结
        let tx = size / 2; let knotY = size * 0.37
        ctx.move(to: CGPoint(x: tx - size * 0.05, y: knotY + size * 0.03))
        ctx.addLine(to: CGPoint(x: tx + size * 0.05, y: knotY + size * 0.03))
        ctx.addLine(to: CGPoint(x: tx, y: knotY)); ctx.closePath(); ctx.fillPath()
        // 绳子（从打结向下延伸）
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: tx, y: knotY))
        ctx.addLine(to: CGPoint(x: tx - size * 0.03, y: size * 0.04))
        ctx.strokePath()
        ctx.restoreGState()
        return ctx.makeImage()!
    }

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

    static func fireBlast(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 1, y: size * 0.2, width: size - 2, height: size * 0.6))
        return ctx.makeImage()!
    }

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
        // 前翅（上对翅）
        ctx.fillEllipse(in: CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.38, height: s * 0.25))
        ctx.fillEllipse(in: CGRect(x: s * 0.54, y: s * 0.08, width: s * 0.38, height: s * 0.25))
        // 后翅（下对翅）
        ctx.fillEllipse(in: CGRect(x: s * 0.14, y: s * 0.28, width: s * 0.26, height: s * 0.28))
        ctx.fillEllipse(in: CGRect(x: s * 0.6, y: s * 0.28, width: s * 0.26, height: s * 0.28))
        // 身体
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - s * 0.025, y: s * 0.18, width: s * 0.05, height: s * 0.45))
        // 触角
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

    static func note(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        // 音符头（椭圆）
        ctx.fillEllipse(in: CGRect(x: size * 0.15, y: size * 0.1, width: size * 0.45, height: size * 0.35))
        // 符干（竖线）
        ctx.fill(CGRect(x: size * 0.5, y: size * 0.3, width: size * 0.08, height: size * 0.65))
        // 符尾（弧线）
        ctx.saveGState(); ctx.translateBy(x: size * 0.54, y: size * 0.85)
        ctx.rotate(by: -0.2)
        ctx.fillEllipse(in: CGRect(x: 0, y: -size * 0.06, width: size * 0.25, height: size * 0.12))
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    static func paper(size: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: size * 0.15, y: 0, width: size * 0.7, height: size))
        return ctx.makeImage()!
    }
}
