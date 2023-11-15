//
//  StatusItemController.swift
//  Battery Thing
//
//  Created by Curtis Hard on 14/07/2021.
//

import Foundation
import AppKit

// 实践发现NSStatusItem.autosaveName 在设置 isVisible=false 或 true后，并不能恢复到原来的位置，同下面这个issue
// https://github.com/feedback-assistant/reports/issues/200
// 也是同样使用了这个issue中 @curthard89 的方法来解决这个问题
class StatusBarController: NSObject {
    static var system = StatusBarController()
    
    lazy private(set) var items = Set<NSStatusItem>()
    private let defaults = UserDefaults.standard
    
    deinit {
        for item in items {
            removeObserver(autosaveName: item.autosaveName)
        }
    }
    
    func removeStatusItem(_ item: NSStatusItem) {
        items.remove(item)
    }
    
    func statusItem(autosaveName: NSStatusItem.AutosaveName,
                    width: CGFloat) -> NSStatusItem {
        // it is important we load the default and then add an observer
        // before we ask the os for the item as the item will instantly
        // remove the user preference
        addObserver(autosaveName: autosaveName)
        let item = NSStatusBar.system.statusItem(withLength: width)
        items.insert(item)
        
        // this is the line that will cause the bug
        item.autosaveName = autosaveName
        return item
    }

    
    fileprivate func defaultsKey(_ autosaveName: NSStatusItem.AutosaveName) -> String {
        return "NSStatusItem Preferred Position \(autosaveName)"
    }
    
    fileprivate func addObserver(autosaveName string: NSStatusItem.AutosaveName) {
        let options: NSKeyValueObservingOptions = [.new, .old]
        defaults.addObserver(self, forKeyPath: defaultsKey(string),
                             options: options,
                             context: nil)
    }
    
    fileprivate func removeObserver(autosaveName: NSStatusItem.AutosaveName) {
        defaults.removeObserver(self, forKeyPath: defaultsKey(autosaveName))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                     change: [NSKeyValueChangeKey : Any]?,
                                     context: UnsafeMutableRawPointer?) {
        // settings .autosaveName on the item after it has been created will
        // cause null to be set for the position, this will simply write back
        // the old value to the defaults
        if let dict = change, dict[.newKey] is NSNull, let oldPosition = dict[.oldKey] {
            defaults.set(oldPosition, forKey: keyPath!)
        }
    }
    
}
