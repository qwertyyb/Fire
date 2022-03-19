//
//  FireCandidatesView.swift
//  Fire
//
//  Created by 虚幻 on 2019/9/16.
//  Copyright © 2019 qwertyyb. All rights reserved.
// 

import SwiftUI
import Defaults

func getShownCode(candidate: Candidate, origin: String) -> String {
    if candidate.type == "py" || !candidate.code.hasPrefix(origin) {
        return "(\(candidate.code))"
    }
    if candidate.code.hasPrefix(origin) {
        return candidate.code.count > origin.count
            ? "~\(String(candidate.code.suffix(candidate.code.count - origin.count)))"
            : ""
    }
    return ""
}

struct CandidateView: View {
    var candidate: Candidate
    var index: Int
    var origin: String
    var selected: Bool = false

    var body: some View {
        let indexColor = selected
            ? ThemeConfig.current.selectedIndexColor
            : ThemeConfig.current.candidateIndexColor
        let textColor = selected
            ? ThemeConfig.current.selectedTextColor
            : ThemeConfig.current.candidateTextColor
        let codeColor = selected
            ? ThemeConfig.current.selectedCodeColor
            : ThemeConfig.current.candidateCodeColor

        return HStack(alignment: .center, spacing: 2) {
            Text("\(index + 1).")
                .font(.system(size: ThemeConfig.current.fontSize))
                .foregroundColor(Color(indexColor))
            Text(candidate.text)
                .font(.system(size: ThemeConfig.current.fontSize))
                .foregroundColor(Color(textColor))
            if Defaults[.wubiCodeTip] {
                Text(getShownCode(candidate: candidate, origin: origin))
                    .font(.system(size: ThemeConfig.current.fontSize))
                    .foregroundColor(Color(codeColor))
            }
        }
        .fixedSize()
        .onTapGesture {
            NotificationCenter.default.post(
                name: Fire.candidateSelected,
                object: nil,
                userInfo: [
                    "candidate": candidate,
                    "index": index
                ]
            )
        }
    }
}

struct CandidatesView: View {
    var candidates: [Candidate]
    var origin: String
    var hasPrev: Bool = false
    var hasNext: Bool = false

    let direction = Defaults[.candidatesDirection]

    var _candidatesView: some View {
        ForEach(Array(candidates.enumerated()), id: \.element) { (index, candidate) -> CandidateView in
            CandidateView(
                candidate: candidate,
                index: index,
                origin: origin,
                selected: index == 0
            )
        }
    }

    var _indicator: some View {
        if Defaults[.candidatesDirection] == CandidatesDirection.horizontal {
            return AnyView(VStack(spacing: 0) {
                Image(hasPrev ? "arrowUp" : "arrowUpOff")
                    .resizable()
                    .frame(width: 10, height: 10, alignment: .center)
                    .onTapGesture {
                        if !hasPrev { return }
                        NotificationCenter.default.post(
                            name: Fire.prevPageBtnTapped,
                            object: nil
                        )
                    }
                Image(hasNext ? "arrowDown" : "arrowDownOff")
                    .resizable()
                    .frame(width: 10, height: 10, alignment: .center)
                    .onTapGesture {
                        if !hasNext { return }
                        print("next")
                        NotificationCenter.default.post(
                            name: Fire.nextPageBtnTapped,
                            object: nil
                        )
                    }
            })
        }
        return AnyView(HStack(spacing: 4) {
            Image(hasPrev ? "arrowUp" : "arrowUpOff")
                .resizable()
                .frame(width: 10, height: 10, alignment: .center)
                .rotationEffect(Angle(degrees: -90), anchor: .center)
                .onTapGesture {
                    if !hasPrev { return }
                    NotificationCenter.default.post(
                        name: Fire.prevPageBtnTapped,
                        object: nil
                    )
                }
            Image(hasNext ? "arrowDown" : "arrowDownOff")
                .resizable()
                .frame(width: 10, height: 10, alignment: .center)
                .rotationEffect(Angle(degrees: -90), anchor: .center)
                .onTapGesture {
                    if !hasNext { return }
                    print("next")
                    NotificationCenter.default.post(
                        name: Fire.nextPageBtnTapped,
                        object: nil
                    )
                }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6, content: {
            if Defaults[.showCodeInWindow] {
                Text(origin)
                    .font(.system(size: ThemeConfig.current.fontSize))
                    .foregroundColor(Color(ThemeConfig.current.originCodeColor))
                    .fixedSize()
            }
            if Defaults[.candidatesDirection] == CandidatesDirection.horizontal {
                HStack(alignment: .center, spacing: 8) {
                    _candidatesView
                    _indicator
                }
                .fixedSize()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    _candidatesView
                    _indicator
                }
                .fixedSize()
            }
        })
            .padding(.top, ThemeConfig.current.windowPaddingTop)
            .padding(.bottom, ThemeConfig.current.windowPaddingBottom)
            .padding(.leading, ThemeConfig.current.windowPaddingLeft)
            .padding(.trailing, ThemeConfig.current.windowPaddingRight)
            .fixedSize()
            .background(Color(ThemeConfig.current.windowBackgroundColor))
            .cornerRadius(ThemeConfig.current.windowBorderRadius, antialiased: true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        CandidatesView(candidates: [
            Candidate(code: "a", text: "工", type: "wb"),
            Candidate(code: "ab", text: "戈", type: "wb"),
            Candidate(code: "abc", text: "啊", type: "wb"),
            Candidate(code: "abcg", text: "阿", type: "wb"),
            Candidate(code: "addd", text: "吖", type: "wb")
        ], origin: "a")
    }
}
