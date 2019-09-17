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
    var charstr:String {
        set (val) {
            Fire.shared.inputstr = val
        }
        get {
            return Fire.shared.inputstr
        }
    }
    let candidate = Fire.shared.candidates
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        NSLog("init controller")
        super.init(server: server, delegate: delegate, client: inputClient)
        candidate.setClient(inputClient);
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
            if charstr.count >  0 {
            } else {
                candidate.hide()
            }
            return true
        }
        
        // 当前输入的是数字,选择当前候选列表中的第N个字符
        if try! NSRegularExpression(pattern: "^[1-9]+$").firstMatch(in: string, options: [], range: NSMakeRange(0, string.count)) != nil {
            let selected = Fire.shared.candidatesTexts[Int(string)!]
            insertText(selected)
            charstr = ""
            candidate.hide()
            return true
        }
        if keyCode == kVK_Return {
            // 插入原字符
            NSLog("compose  str: %@", charstr)
            insertText(charstr)
            return true
        }
        if keyCode == kVK_Space {
            // 插入转换后字符
            let first = Fire.shared.candidatesTexts.first
            if first != nil {
                NSLog("compose  str: %@", first!)
                insertText(first!)
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
    
    func insertText(_ string: String) {
        client().insertText(string, replacementRange: NSMakeRange(NSNotFound, NSNotFound))
        self.charstr = ""
        self.candidate.hide()
    }
    
    override func recognizedEvents(_ sender: Any!) -> Int {
        NSLog("recognizedEvents")
        return super.recognizedEvents(sender)
    }
    
    override func activateServer(_ sender: Any!) {
        print(sender)
        NSLog("active server")
    }
    
    override func deactivateServer(_ sender: Any!) {
        candidate.hide()
    }
    
}
