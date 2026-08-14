import Foundation
import Testing
@testable import Fire

struct FirePunctuationTransformerTests {
    @Test func transform_enUs_returnsHalfWidth() {
        guard case .commit(let text)? = PunctuationMappingStore.transform(
            ",",
            mode: .enUs,
            mappingType: .default,
            customMapping: [:]
        ) else {
            Issue.record("expected commit")
            return
        }
        #expect(text == ",")
        #expect(PunctuationMappingStore.transform(
            "unknown",
            mode: .enUs,
            mappingType: .default,
            customMapping: [:]
        ) == nil)
    }

    @Test func transform_zhhans_defaultMapping() {
        guard case .commit(let text)? = PunctuationMappingStore.transform(
            ",",
            mode: .zhhans,
            mappingType: .default,
            customMapping: [:]
        ) else {
            Issue.record("expected commit")
            return
        }
        #expect(text == "，")

        guard case .candidates(let list)? = PunctuationMappingStore.transform(
            "[",
            mode: .zhhans,
            mappingType: .default,
            customMapping: [:]
        ) else {
            Issue.record("expected candidates")
            return
        }
        #expect(list == ["[", "【", "「", "『", "〔"])
    }

    @Test func transform_zhhans_customMapping() {
        guard case .commit(let text)? = PunctuationMappingStore.transform(
            ",",
            mode: .zhhans,
            mappingType: .custom,
            customMapping: [",": .commit("，")]
        ) else {
            Issue.record("expected commit")
            return
        }
        #expect(text == "，")
        #expect(PunctuationMappingStore.transform(
            ".",
            mode: .zhhans,
            mappingType: .custom,
            customMapping: [",": .commit("，")]
        ) == nil)
    }

    @Test func punctuationMode_decodesLegacyCustomAsZhhans() throws {
        let data = Data("\"custom\"".utf8)
        let mode = try JSONDecoder().decode(PunctuationMode.self, from: data)
        #expect(mode == .zhhans)
    }
}
