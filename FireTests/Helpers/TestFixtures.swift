@testable import Fire

enum TestFixtures {
    static func makeRootState(
        config: MockEngineConfig = MockEngineConfig(),
        store: MockEngineStore = MockEngineStore(),
        dict: MockEngineDictManager = MockEngineDictManager()
    ) -> (root: RootState, store: MockEngineStore, dict: MockEngineDictManager, config: MockEngineConfig) {
        let engine = Engine()
        engine.store = store
        let root = RootState(
            dict: dict,
            config: config,
            store: store,
            engine: engine,
            punctuationTransformer: FirePunctuationTransformer()
        )
        return (root, store, dict, config)
    }

    static func candidate(_ text: String, code: String? = nil) -> Candidate {
        Candidate(code: code ?? text, text: text, type: .user)
    }
}
