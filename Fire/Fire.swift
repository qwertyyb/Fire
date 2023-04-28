//
//  Fire.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/15.
//  Copyright © 2019 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit
import Sparkle
import Defaults

let kConnectionName = "Fire_1_Connection"

class Fire: NSObject {
    // 逻辑
    static let candidateInserted = Notification.Name("Fire.candidateInserted")
    static let inputModeChanged = Notification.Name("Fire.inputModeChanged")

    var inputMode: InputMode = .zhhans

    func transformPunctuation(_ origin: String) -> String? {
        let isPunctuation = punctuation.keys.contains(origin)
        if !isPunctuation {
            return nil
        }
        let mode = Defaults[.punctuationMode]
        if mode == .enUs {
            return origin
        }
        if mode == .zhhans {
            return punctuation[origin]
        }
        if mode == .custom {
            return Defaults[.customPunctuationSettings][origin]
        }
        return nil
    }

    override init() {
        super.init()
        _ = InputSource.shared.onSelectChanged { selected in
            StatusBar.shared.refresh()
            if selected {
                self.toastCurrentMode()
            }
        }
    }

    func toggleInputMode(_ nextInputMode: InputMode? = nil, showTip: Bool = true) {
        if nextInputMode != nil, self.inputMode == nextInputMode {
            return
        }
        let oldVal = self.inputMode
        if let nextInputMode = nextInputMode, nextInputMode != self.inputMode {
            self.inputMode = nextInputMode
        } else {
            self.inputMode = inputMode == .enUS ? .zhhans : .enUS
        }
        if showTip {
            toastCurrentMode()
        }
        StatusBar.shared.refresh()
        NotificationCenter.default.post(name: Fire.inputModeChanged, object: nil, userInfo: [
            "oldVal": oldVal,
            "val": self.inputMode,
            "label": self.inputMode == .enUS ? "英" : "中"
        ])
    }

    func toastCurrentMode() {
        let text = inputMode == .enUS ? "英" : "中"

        // 不用考虑getOriginPoint返回的坐标位于屏幕外的情况
        // 这种情况一般说明，当前没有输入框可以输入，不需要关注输入法，所以提示窗显示在屏幕外也没有关系
        let position = CandidatesWindow.shared.inputController?.getOriginPoint() ?? NSEvent.mouseLocation

        Utils.shared.toast?.show(text, position: position)
    }

    var server: IMKServer = IMKServer.init(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
    func getCandidates(origin: String = String(), page: Int = 1) -> (candidates: [Candidate], hasNext: Bool) {
        if origin.count <= 0 {
            return ([], false)
        }
        let (candidates, hasNext) = DictManager.shared.getCandidates(query: origin, page: page)
        let transformed = candidates.map { (candidate) -> Candidate in
            if candidate.type == .user {
                return Candidate(code: candidate.code, text: candidate.text, type: .user)
            }
            return candidate
        }
        return (transformed, hasNext)
    }

    static let shared = Fire()
}
