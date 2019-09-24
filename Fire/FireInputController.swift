//
//  FireInputController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

class FireInputController: IMKInputController {
    private var _composedString = ""
    var charstr:String {
        set (val) {
            print(client()?.uniqueClientIdentifierString());
            client()?.setMarkedText(val, selectionRange: selectionRange(), replacementRange: replacementRange())
            Fire.shared.inputstr = val
        }
        get {
            return Fire.shared.inputstr
        }
    }
    let candidate = Fire.shared.candidates
    
//    override func originalString(_ sender: Any!) -> NSAttributedString! {
//        return NSAttributedString(string: charstr)
//    }
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        NSLog("init controller")
        super.init(server: server, delegate: delegate, client: inputClient)
    }
    
    override func inputText(_ string: String!, key keyCode: Int, modifiers flags: Int, client sender: Any!) -> Bool {
        NSLog("%@", charstr)
        let reg = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
        let match = reg.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))
        
        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  charstr.count <= 0 && match == nil {
            return false
        }
        // 当前输入的是英文字符,附加到之前
        let candidate = Fire.shared.candidates
        if (match != nil) {
            charstr += string
            return true
        }
        
        // 删除最后一个字符
        if keyCode == kVK_Delete && charstr.count > 0 {
            charstr = String(charstr.dropLast())
//            client()?.setMarkedText("", selectionRange: NSMakeRange(NSNotFound, NSNotFound), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
            if charstr.count == 0 {
                candidate.hide()
            }
            return true
        }
        
        // 当前输入的是数字,选择当前候选列表中的第N个字符
        if try! NSRegularExpression(pattern: "^[1-9]+$").firstMatch(in: string, options: [], range: NSMakeRange(0, string.count)) != nil {
            let selected = Fire.shared.candidatesTexts[Int(string)!]
            updateComposedString(selected)
            commitComposition(sender)
            charstr = ""
            candidate.hide()
            return true
        }
        if keyCode == kVK_Return {
            // 插入原字符
            NSLog("compose  str: %@", charstr)
            updateComposedString(charstr)
            commitComposition(sender)
            return true
        }
        if keyCode == kVK_Space {
            // 插入转换后字符
            let first = Fire.shared.candidatesTexts.first
            if first != nil {
                NSLog("compose  str: %@", first!)
                updateComposedString(first!)
                commitComposition(sender)
                charstr = ""
                candidate.hide()
            }
            return true
        }
        if keyCode == kVK_ANSI_Equal {
            candidate.moveRightAndModifySelection(sender)
            return true
        }
        if keyCode == kVK_ANSI_Minus {
            candidate.moveLeftAndModifySelection(sender)
            return true
        }
        return false
    }
    override func commitComposition(_ sender: Any!) {
        client().insertText(composedString(sender), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
        self.charstr = ""
        self.candidate.hide()
    }
    
    override func selectionRange() -> NSRange {
        return NSMakeRange(_composedString.count, NSNotFound)
    }
    
    override func replacementRange() -> NSRange {
        return NSMakeRange(NSNotFound, NSNotFound)
    }
    
    override func composedString(_ sender: Any!) -> Any! {
        return NSAttributedString(string: _composedString)
    }
    
    func updateComposedString(_ string: String) {
        _composedString = string
    }
    
    override func recognizedEvents(_ sender: Any!) -> Int {
        NSLog("recognizedEvents")
        return super.recognizedEvents(sender)
    }
    
    override func activateServer(_ sender: Any!) {
        print(client()?.bundleIdentifier()!)
        candidate.setClient(sender);
        NSLog("active server")
    }
    
    override func deactivateServer(_ sender: Any!) {
        candidate.hide()
    }
    
    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Fire")
        menu.addItem(NSMenuItem(title: "哈哈哈", action: nil, keyEquivalent: ""))
        return menu
    }
    
}
