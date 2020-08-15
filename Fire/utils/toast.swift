//
//  toast.swift
//  Fire
//
//  Created by 虚幻 on 2020/8/15.
//  Copyright © 2020 qwertyyb. All rights reserved.
//11

import AppKit

let window = NSWindow()

func toast () {
    window.acceptsMouseMovedEvents = false
//    window.center()
    let visualEffect = NSVisualEffectView()
    visualEffect.translatesAutoresizingMaskIntoConstraints = false
    visualEffect.material = .appearanceBased
    visualEffect.state = .active
    visualEffect.wantsLayer = true
    visualEffect.layer?.masksToBounds = true
    visualEffect.layer?.cornerRadius = 16.0

    window.hasShadow = false
    window.titleVisibility = .hidden
    window.styleMask.remove(.titled)
    window.backgroundColor = .clear
    window.isMovableByWindowBackground = true

    window.contentView?.addSubview(visualEffect)

    guard let constraints = window.contentView else {
      return
    }

    visualEffect.leadingAnchor.constraint(equalTo: constraints.leadingAnchor).isActive = true
    visualEffect.trailingAnchor.constraint(equalTo: constraints.trailingAnchor).isActive = true
    visualEffect.topAnchor.constraint(equalTo: constraints.topAnchor).isActive = true
    visualEffect.bottomAnchor.constraint(equalTo: constraints.bottomAnchor).isActive = true
    
    window.setFrame(NSMakeRect(100, 100, 160, 160), display: true)
    window.center()
    window.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel() + 10))
    window.orderFront(nil)
}
