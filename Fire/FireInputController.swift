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
    var selected:String = ""
    let condidate = Fire.shared.candidates
    
    override func inputText(_ string: String!, key keyCode: Int, modifiers flags: Int, client sender: Any!) -> Bool {
        NSLog("%@", charstr)
        let reg = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
        let match = reg.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))
        
        if  charstr.count <= 0 && match == nil {
            return false
        }
        
        let candidate = Fire.shared.candidates
        if (match != nil) {
            charstr += string
            candidate.update()
            candidate.show(sender: client())
            return true
        }
        
        if keyCode == kVK_Delete && charstr.count > 0 {
            charstr = String(charstr.dropLast())
            if charstr.count >  0 {
                candidate.update()
                candidate.show(sender: client())
            } else {
                candidate.hide()
            }
            return true
        }
        if try! NSRegularExpression(pattern: "^[1-9]+$").firstMatch(in: string, options: [], range: NSMakeRange(0, string.count)) != nil {
            selected = (candidates(sender) as! [String])[Int(string)!]
            commitComposition(sender)
            charstr = ""
            candidate.hide()
            return true
        }
        
        if keyCode == kVK_Return || keyCode == kVK_Space {
            NSLog("compose  str: %@", charstr)
            commitComposition(sender)
            charstr = ""
            candidate.hide()
            return true
        }
        if keyCode == kVK_Delete {
            charstr = String(charstr.dropLast())
            return true
        }
        if keyCode == kVK_RightArrow {
//            candidate.selectCandidate(2)
            candidate.moveRightAndModifySelection(sender)
            return true
        }
        if keyCode == kVK_LeftArrow {
            candidate.moveLeftAndModifySelection(sender)
            return true
        }
        if keyCode == kVK_UpArrow {
            
            candidate.pageUpAndModifySelection(sender)
            return true
        }
        if keyCode == kVK_DownArrow {
            candidate.pageDownAndModifySelection(sender)
            return true
        }
//        candidate.update()
        return false
    }
    
    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        NSLog("changed: %@", candidateString.string)
        selected = candidateString.string
    }
    override func candidateSelected(_ candidateString: NSAttributedString!) {
        NSLog("selected: %@", candidateString)
    }
    
    override func commitComposition(_ sender: Any!) {
        if charstr.count > 0 {
            client().insertText(composedString(sender), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
        }
    }
    
    override func composedString(_ sender: Any!) -> Any! {
        return selected
    }
    
    override func candidates(_ sender: Any!) -> [Any]! {
        return ["我", "b", "c", "d", "e", "f", "g", "h", "l", "m", "n", "i", "j", "k", "o", "p", "q"]
    }
    override func annotationSelected(_ annotationString: NSAttributedString!, forCandidate candidateString: NSAttributedString!) {
        
        NSLog("annotation selected: %@", annotationString)
    }
    
    override func deactivateServer(_ sender: Any!) {
//        condidate.hide()
    }
    

//    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
//        Fire.shared.candidate.showAnnotation(NSAttributedString(string: charstr))
//    }

    
}
