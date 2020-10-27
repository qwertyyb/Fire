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
    if candidate.type == "py" {
        return "(\(candidate.code))"
    }
    return candidate.code.hasPrefix(origin) && candidate.code.count > origin.count
        ? "~\(String(candidate.code.suffix(candidate.code.count - origin.count)))" : ""
}

struct CandidateView: View {
    var candidate: Candidate
    var index: Int
    var origin: String
    var selected: Bool = false
    var body: some View {
        let mainColor = selected
            ? Color(red: 0.863, green: 0.078, blue: 0.235)
            : Color(red: 0.23, green: 0.23, blue: 0.23)

        return HStack(alignment: .center, spacing: 2) {
            Text("\(index).")
                .font(.system(size: 20))
                .foregroundColor(mainColor)
            Text(candidate.text)
                .font(.system(size: 20))
                .foregroundColor(mainColor)
            if Defaults[.wubiCodeTip] {
                Text(getShownCode(candidate: candidate, origin: origin))
                    .font(.system(size: 18))
                    .foregroundColor(
                        .init(Color.RGBColorSpace.sRGBLinear, red: 0.3, green: 0.3, blue: 0.3, opacity: 0.8)
                    )
            }
        }
        .fixedSize()
    }
}

struct CandidatesView: View {
    var candidates: [Candidate]
    var origin: String

    let direction = Defaults[.candidatesDirection]

    var _candidatesView: some View {
        var index = 0
        return ForEach(candidates, id: \.self) { (candidate) -> CandidateView in
            index += 1
            return CandidateView(
                candidate: candidate,
                index: index,
                origin: origin,
                selected: index == 1
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6, content: {
            if Defaults[.showCodeInWindow] {
                Text(origin)
                    .font(.system(size: 20))
                    .foregroundColor(.init(red: 0.3, green: 0.3, blue: 0.3))
                    .fixedSize()
            }
            if Defaults[.candidatesDirection] == CandidatesDirection.horizontal {
                HStack(alignment: .center, spacing: 8) {
                    _candidatesView
                }
                .fixedSize()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    _candidatesView
                }
                .fixedSize()
            }
        })
        .padding(.horizontal, 10.0)
        .padding(.vertical, 6)
        .fixedSize()
        .background(Color.white)
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
        .shadow(color: .red, radius: 6, x: 6, y: 6)
    }
}
