//
//  InputModeCache.swift
//  Fire
//
//  Created by qwertyyb on 2023/11/7.
//
import Defaults

class InputModeCache {
    let capacity = 100
    private var cache: [String: InputMode] = [:]
    private var keys: [String] = []
    
    private init() {
        loadFromUserDefaults()
    }
    
    func get(_ key: String) -> InputMode? {
        if let value = cache[key] {
            updateKeyOrder(key)
            return value
        }
        return nil
    }
    
    func put(_ key: String, _ value: InputMode) {
        if cache[key] == nil {
            if keys.count >= capacity {
                let oldestKey = keys.removeFirst()
                cache[oldestKey] = nil
            }
            keys.append(key)
        } else {
            updateKeyOrder(key)
        }
        cache[key] = value
        saveToUserDefaults()
    }
    
    private func updateKeyOrder(_ key: String) {
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
            keys.append(key)
            saveToUserDefaults()
        }
    }
    
    private func saveToUserDefaults() {
        Defaults[.keepAppInputMode_keys] = keys
        Defaults[.keepAppInputMode_cache] = cache
    }
    
    private func loadFromUserDefaults() {
        keys = Defaults[.keepAppInputMode_keys]
        cache = Defaults[.keepAppInputMode_cache]
    }
    
    static let shared = InputModeCache()
}
