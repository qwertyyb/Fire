//
//  ApplicationSettingCache.swift
//  Fire
//
//  Created by 虚幻 on 2021/7/17.
//  Copyright © 2021 qwertyyb. All rights reserved.
//

import Foundation

class ApplicationSettingCache {

    private var cache: [String: ApplicationSettingItem] = [:]

    private var maxCount: Int = 50

    private func handleRemove() {
        if cache.count <= maxCount { return }
        guard let oldest = cache.sorted(by: { a, b in
            a.value.createdTimestamp < b.value.createdTimestamp
        }).first else { return }
        cache.removeValue(forKey: oldest.key)
    }

    func add(bundleIdentifier: String, setting: ApplicationSettingItem) {
        cache[bundleIdentifier] = setting
    }
    func get(bundleIdentifier: String) -> ApplicationSettingItem? {
        guard let setting = cache[bundleIdentifier] else { return nil }
        cache.removeValue(forKey: bundleIdentifier)
        add(
            bundleIdentifier: bundleIdentifier,
            setting: ApplicationSettingItem(bundleId: setting.bundleIdentifier, inputMs: setting.inputModeSetting)
        )
        handleRemove()
        return setting
    }
}
