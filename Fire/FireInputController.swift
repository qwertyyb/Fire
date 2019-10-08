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

enum InputMode {
    case ZhHans
    case En
}

let punctution: [String: String] = [
    ",": "，",
    ".": "。",
    "/": "、",
    ";": "；",
    "'": "‘",
    "[": "［",
    "]": "］",
    "`": "｀",
    "!": "！",
    "@": "‧",
    "#": "＃",
    "$": "￥",
    "%": "％",
    "^": "……",
    "&": "＆",
    "*": "×",
    "(": "（",
    ")": "）",
    "-": "－",
    "_": "——",
    "+": "＋",
    "=": "＝",
    "~": "～",
    "{": "｛",
    "\\": "、",
    "|": "｜",
    "}": "｝",
    ":": "：",
    "\"": "“",
    "<": "《",
    ">": "》",
    "?": "？"
]

class FireInputController: IMKInputController {
    private var _originalString = "" { 
        didSet (val) {
            let value = originalString(client())!.string
            NSLog("original string changed: \(value )")
//            updateComposition()
            let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSMakeRange(NSNotFound,0))
            let text = NSAttributedString(string: value.count > 0 ? " " : "", attributes: (attrs as! [NSAttributedString.Key : Any]))
            client()?.setMarkedText(text, selectionRange: NSMakeRange(NSNotFound, text.length), replacementRange: replacementRange())
            if value.count > 0 {
                self.self._candidatesWindow.updateWindow(origin: self.getOriginPoint(), code: value, candidates: self.candidates(self.client()) as! [Candidate])
                Fire.shared.getCandidateFromNetwork(origin: value, sender: client())
            } else {
                _candidatesWindow.close()
            }
        }
    }
    private var  _composedString = ""
    private let _candidatesWindow = FireCandidatesWindow.shared
    private var _mode: InputMode = .ZhHans
    private var _modeWindow: NSWindow
    private var _closeModeWindowTimer: Timer? = nil
    private var _lastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        
        let window = NSWindow()
        window.styleMask = .init(arrayLiteral: .borderless, .fullSizeContentView)
        window.contentView = NSTextField(labelWithString: "中")
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        _modeWindow = window
        
        super.init(server: server, delegate: delegate, client: inputClient)
        
        NSLog("observer: NetCandidatesUpdate-\(client().bundleIdentifier() ?? "Fire")")
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "NetCandidatesUpdate-\(client().bundleIdentifier() ?? "Fire")"), object: nil, queue: nil) { (notification) in
            let list = notification.object as! [Candidate]
            DispatchQueue.main.async {
                self._candidatesWindow.updateNetCandidateView(candidate: list.count > 0 ? list.first! : nil)
            }
        }
    }
    
    override func selectionRange() -> NSRange {
        return NSMakeRange(0, originalString(client()).length)
    }
    
    override func commitComposition(_ sender: Any!) {
        NSLog("commitComposition: %@", composedString(sender) as! NSAttributedString)
        client().insertText(composedString(sender), replacementRange: replacementRange())
        clean()
    }
    
    override func originalString(_ sender: Any!) -> NSAttributedString! {
        return NSAttributedString(string: _originalString)
    }
    
    override func replacementRange() -> NSRange {
        return NSMakeRange(NSNotFound, NSNotFound)
    }
    
    override func activateServer(_ sender: Any!) {
        client()?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
        NSLog("active server: \(client()!.bundleIdentifier()!)")
    }
    
    private func getOriginPoint() -> NSPoint {
        let ptr = UnsafeMutablePointer<NSRect>.allocate(capacity: 1)
        ptr.pointee = NSRect()
        client().attributes(forCharacterIndex: 0, lineHeightRectangle: ptr)
        let rect = ptr.pointee
        let origin = NSPoint(x: rect.origin.x, y: rect.origin.y)
        ptr.deallocate()
        return origin
    }
    
    func toggleMode() {
        if self._closeModeWindowTimer != nil {
            self._closeModeWindowTimer!.invalidate()
            self._closeModeWindowTimer = nil
        }
        
        _mode = _mode == .ZhHans ? InputMode.En : InputMode.ZhHans
        _originalString = ""
        _composedString = ""
        
        
        if self._modeWindow.isVisible {
            self._modeWindow.close()
        }
        let text = _mode == .ZhHans ? "中" : "A"
        (self._modeWindow.contentView as! NSTextField).attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key.font: NSFont.userFont(ofSize: 20)!,
            ]
        )
        let origin = getOriginPoint()
        self._modeWindow.setFrame(NSMakeRect(origin.x + 2, origin.y - 26, _mode == .ZhHans ? 24 : 18, 24), display: true)
        self._modeWindow.orderFront(nil)
        self._closeModeWindowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (timer) in
            self._modeWindow.close()
            self._closeModeWindowTimer = nil
        }
        NSLog("toggle mode: \(_mode)")
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // 切换中英文输入
        if event.type == .flagsChanged  {
            if event.modifierFlags == .init(rawValue: 0) && _lastModifier == .shift {  // shift键抬起
                self.toggleMode()
            }
            
            _lastModifier = event.modifierFlags
            return false
        }
        _lastModifier = .init(rawValue: 0)
        if event.modifierFlags != .init(rawValue: 0) && event.modifierFlags != .shift {
            return false
        }
        if _lastModifier != .init(rawValue: 0) {
            return false
        }
        if _mode == .En || event.characters == nil {
            return false
        }
        let keyCode = event.keyCode
        
        // 删除最后一个字符
        if keyCode == kVK_Delete  {
            if _originalString.count > 0 {
                _originalString = String(_originalString.dropLast())
                return true
            }
            return false
        }
        
        let string = event.characters!
        NSLog("string: \(string), keyCode: \(keyCode)")
        
        if _mode == .ZhHans && punctution.keys.contains(string) {
            _composedString = punctution[string]!
            commitComposition(sender)
            return true
        }
        
        
        let reg = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
        let match = reg.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.count))
        
        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  _originalString.count <= 0 && match == nil {
            NSLog("非字符,不做处理,直接返回")
            return false
        }
        // 当前输入的是英文字符,附加到之前
        if (match != nil) {
//            NSLog("输入了英文字符,附加到之前: \(string)")
            _originalString += string
            return true
        }
        
        // 当前输入的是数字,选择当前候选列表中的第N个字符
        if try! NSRegularExpression(pattern: "^[1-9]+$").firstMatch(in: string, options: [], range: NSMakeRange(0, string.count)) != nil {
            let index = Int(string)! - 1
            let candidates = self.candidates(sender)
            if index < candidates!.count {
                _composedString = (candidates![index] as! Candidate).text
                commitComposition(sender)
                _candidatesWindow.close()
            } else {
                _originalString += string
            }
            return true
        }
        if keyCode == kVK_Return {
            // 插入原字符
            _composedString = _originalString
            commitComposition(sender)
            return true
        }
        if keyCode == kVK_Space {
            // 插入转换后字符
            let first = self.candidates(sender).first
            if first != nil {
                _composedString = (first as! Candidate).text
                commitComposition(sender)
                _candidatesWindow.close()
            }
            return true
        }
        return false
    }
    
    override func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }
    
    override func deactivateServer(_ sender: Any!) {
        NSLog("deactivate server: \(client()!.bundleIdentifier()!)")
        clean()
    }
    
    override func menu() -> NSMenu! {
        return (NSApp.delegate as! AppDelegate).menu
    }
    
    override func candidates(_ sender: Any!) -> [Any]! {
        return Fire.shared.getCandidates(origin: self.originalString(sender)!)
    }
    
    override func composedString(_ sender: Any!) -> Any! {
        return NSAttributedString(string: _composedString)
    }
    
    func clean() {
        _originalString = ""
        _composedString = ""
        _candidatesWindow.close()
    }
    override func inputControllerWillClose() {
        clean()
    }
    
}
