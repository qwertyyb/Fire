//
//  FireInputController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

var set = false

class FireInputController: IMKInputController {
    private var _originalString = "" { 
        didSet (val) {
            let value = originalString(client())
            NSLog("original string: \(value!), \(value!.length)")
//            updateComposition()
//            client()?.setMarkedText(originalString(client()), selectionRange: selectionRange(), replacementRange: replacementRange())
            candidatesWindow.updateCondidatesView()
        }
    }
    private var  _composedString = ""
    private let candidatesWindow: FireCandidatesWindow
    
//    override func originalString(_ sender: Any!) -> NSAttributedString! {
//        return NSAttributedString(string: charstr)
//    }
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        candidatesWindow = FireCandidatesWindow()
        super.init(server: server, delegate: delegate, client: inputClient)
        candidatesWindow.updateInputController(inputController: self)
        NSLog("init controller \(client()?.bundleIdentifier() ?? "client")")
        candidatesWindow.setClient(inputClient);
    }
    
    override func inputText(_ string: String!, key keyCode: Int, modifiers flags: Int, client sender: Any!) -> Bool {
        let reg = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
        let match = reg.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))
        
        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  _originalString.count <= 0 && match == nil {
            return false
        }
        // 当前输入的是英文字符,附加到之前
        if (match != nil) {
            _originalString += string
            return true
        }
        
        // 删除最后一个字符
        if keyCode == kVK_Delete && _originalString.count > 0 {
            _originalString = String(_originalString.dropLast())
            if _originalString.count >  0 {
            } else {
                candidatesWindow.close()
            }
            return true
        }
        
        // 当前输入的是数字,选择当前候选列表中的第N个字符
        if try! NSRegularExpression(pattern: "^[1-9]+$").firstMatch(in: string, options: [], range: NSMakeRange(0, string.count)) != nil {
            _composedString = (self.candidates(sender)[Int(string)! - 1] as! Candidate).text
            NSLog("number key hit")
            commitComposition(sender)
            _originalString = ""
            candidatesWindow.close()
            return true
        }
        if keyCode == kVK_Return {
            // 插入原字符
            NSLog("return key hit")
            _composedString = _originalString
            commitComposition(sender)
            return true
        }
        if keyCode == kVK_Space {
            NSLog("space key hit")
            // 插入转换后字符
            let first = self.candidates(sender).first
            if first != nil {
                _composedString = (first as! Candidate).text
                commitComposition(sender)
                _originalString = ""
                candidatesWindow.close()
            }
            return true
        }
        if keyCode == kVK_ANSI_Equal {
            candidatesWindow.moveRightAndModifySelection(sender)
            return true
        }
        if keyCode == kVK_ANSI_Minus {
            candidatesWindow.moveLeftAndModifySelection(sender)
            return true
        }
        return false
    }
    
    override func selectionRange() -> NSRange {
        return NSMakeRange(NSNotFound, originalString(client()).length)
    }
    
    override func commitComposition(_ sender: Any!) {
        NSLog("commitComposition: %@", composedString(sender) as! NSString)
        client().insertText(composedString(sender), replacementRange: replacementRange())
        self._originalString = ""
        self.candidatesWindow.close()
    }
    
    override func originalString(_ sender: Any!) -> NSAttributedString! {
        print("originString called: \(_originalString)")
        return NSAttributedString(string: _originalString)
    }
    
    override func replacementRange() -> NSRange {
        return NSMakeRange(NSNotFound, NSNotFound)
    }
    
    override func activateServer(_ sender: Any!) {
        print(client()!.bundleIdentifier()!)
        client()?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
        NSLog("active server")
    }
    
//    override func recognizedEvents(_ sender: Any!) -> Int {
//        return Int(NSEvent.EventType.keyDown.rawValue | NSEvent.EventType.keyUp.rawValue | NSEvent.EventType.flagsChanged.rawValue)
//    }
    
    override func deactivateServer(_ sender: Any!) {
        NSLog("deactivate server")
        candidatesWindow.close()
    }
    
    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Fire")
        menu.addItem(NSMenuItem.init(title: "首选项", action: nil, keyEquivalent: ""))
        return menu
    }
    
    override func candidates(_ sender: Any!) -> [Any]! {
        return Fire.shared.getCandidates(origin: self.originalString(sender)!)
    }
    
    override func composedString(_ sender: Any!) -> Any! {
        return NSString(string: _composedString)
    }
    override func inputControllerWillClose() {
        _originalString = ""
    }
}
