//
//  FireInputController.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit
import Sparkle

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
    private var  _composedString = ""
    private let _candidatesWindow = FireCandidatesWindow.shared
    private var _mode: InputMode = .ZhHans
    private var _lastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)
    private var _originalString = "" { 
        didSet {
            if self._page != 1 {
                // code被重新设置时，还原页码为1
                self._page = 1
                return
            }
            let value = originalString(client())!.string
            NSLog("original string changed: \(value )")
            
            // 在输入框中mark一个空格，防止删除输入code的最后一个字符时，把输入框最后面的一个字符删除
            let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSMakeRange(NSNotFound,0))
            let text = NSAttributedString(string: value.count > 0 ? " " : "", attributes: (attrs as! [NSAttributedString.Key : Any]))
            client()?.setMarkedText(text, selectionRange: NSMakeRange(NSNotFound, text.length), replacementRange: replacementRange())

            if value.count > 0 {
                self._candidatesWindow.refresh()
                if Fire.shared.cloudinput {
                    Fire.shared.getCandidateFromNetwork(origin: value, sender: client())
                }
            } else {
                // 没有输入code时，关闭候选框
                _candidatesWindow.close()
            }
        }
    }
    private var _page: Int = 1 {
        didSet(old) {
            guard old == self._page else {
                self._candidatesWindow.refresh()
                return
            }
        }
    }
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        NSLog("[FireInputController] init")
        
        super.init(server: server, delegate: delegate, client: inputClient)
        
        _candidatesWindow.setInputController(self)
        
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
    
    private func getOriginRect() -> NSRect {
        let ptr = UnsafeMutablePointer<NSRect>.allocate(capacity: 1)
        ptr.pointee = NSRect()
        client().attributes(forCharacterIndex: 0, lineHeightRectangle: ptr)
        let rect = ptr.pointee
        let origin = NSMakeRect(rect.origin.x, rect.origin.y - rect.height - 6, rect.width, rect.height)
        ptr.deallocate()
        return origin
    }
    
    func toggleMode() {
        NSLog("[FireInputController]toggle mode: \(_mode)")
        
        // 把当前未上屏的原始code上屏处理
        _composedString = _originalString
        commitComposition(nil)
        
        _mode = _mode == .ZhHans ? InputMode.En : InputMode.ZhHans
        
        let text = _mode == .ZhHans ? "中" : "A"
        
        // 在输入坐标处，显示中英切换提示
        showTips(text, frame: getOriginRect())
    }
    
    func flagChangeHandler(_ event: NSEvent) {
        
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("[FireInputController] handle: \(event.debugDescription)")
        // 只有在shift keyup时，才切换中英文输入, 否则会导致shift+[a-z]大写的功能失效
        if checkShiftKeyUp(event) {
            self.toggleMode()
            return true
        }
        // 监听.flagsChanged事件只为切换中英文，其它情况不处理
        // 当用户已经按下了非shift的修饰键时，不处理
        if event.type == .flagsChanged || (event.modifierFlags != .init(rawValue: 0) && event.modifierFlags != .shift) {
            return false
        }
        
        // 英文输入模式, 不做任何处理
        if _mode == .En {
            return false
        }
        
        // +/-/arrowdown/arrowup翻页
        let keyCode = event.keyCode
        if _mode == .ZhHans && _originalString.count > 0 {
            if keyCode == kVK_ANSI_Equal || keyCode == kVK_DownArrow {
                _page += 1
                return true
            }
            if keyCode == kVK_ANSI_Minus || keyCode == kVK_UpArrow {
                _page = _page > 1 ? _page - 1 : 1
                return true
            }
        }
        
        // 删除键删除字符
        if keyCode == kVK_Delete  {
            if _originalString.count > 0 {
                _originalString = String(_originalString.dropLast())
                return true
            }
            return false
        }
        
        // 获取输入的字符
        let string = event.characters!
        NSLog("string: \(string), keyCode: \(keyCode)")
        
        // 如果输入的字符是标点符号，转换标点符号为中文符号
        if _mode == .ZhHans && punctution.keys.contains(string) {
            _composedString = punctution[string]!
            commitComposition(sender)
            return true
        }
        
        
        let reg = try! NSRegularExpression(pattern: "^[a-zA-Z]+$")
        let match = reg.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.count)
        )
        
        // 当前没有输入非字符并且之前没有输入字符,不做处理
        if  _originalString.count <= 0 && match == nil {
            NSLog("非字符,不做处理,直接返回")
            return false
        }
        // 当前输入的是英文字符,附加到之前
        if (match != nil) {
            _originalString += string
            return true
        }
        
        // 当前输入的是数字,选择当前候选列表中的第N个字符
        if try! NSRegularExpression(
            pattern: "^[1-9]+$").firstMatch(
                in: string,
                options: [],
                range: NSMakeRange(0, string.count)
            ) != nil {
            let index = Int(string)! - 1
            let candidates = self.candidates(sender)
            if index < candidates!.count {
                _composedString = (candidates![index] as! Candidate).text
                commitComposition(sender)
            } else {
                _originalString += string
            }
            return true
        }
        
        // 回车键输入原字符
        if keyCode == kVK_Return {
            // 插入原字符
            _composedString = _originalString
            commitComposition(sender)
            return true
        }
        
        // 空格键输入转换后的中文字符
        if keyCode == kVK_Space {
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
    
    override func candidates(_ sender: Any!) -> [Any]! {
        return Fire.shared.getCandidates(origin: self.originalString(sender)!, page: _page)
    }
    
    override func composedString(_ sender: Any!) -> Any! {
        return NSAttributedString(string: _composedString)
    }
    
    func clean() {
        _originalString = ""
        _composedString = ""
        _page = 1
        _candidatesWindow.close()
    }
    
    override func inputControllerWillClose() {
        clean()
    }
    
    override func activateServer(_ sender: Any!) {
        NSLog("active server: \(client()!.bundleIdentifier()!)")
        client()?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
        _candidatesWindow.setInputController(self)
    }
    
    override func deactivateServer(_ sender: Any!) {
        NSLog("[FireInputController] deactivate server: \(client()!.bundleIdentifier()!)")
        clean()
    }
    
    /* -- menu actions start -- */
    
    @objc func openAbout (_ sender: Any!) {
        NSLog("open about")
        DispatchQueue.main.async {
            NSLog("check updates")
            NSApp.orderFrontStandardAboutPanel(sender)
        }
    }
    
    @objc func checkForUpdates(_ sender: Any!) {
        SUUpdater.shared()?.checkForUpdates(sender)
    }
    
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "关于业火输入法", action: #selector(openAbout(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "检查更新", action: #selector(checkForUpdates(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "首选项", action: #selector(showPreferences(_:)), keyEquivalent: ""))
        return menu
    }
    
}
