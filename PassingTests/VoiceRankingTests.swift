import Foundation
import Testing
@testable import Passing

struct VoiceRankingTests {
    private func voice(_ id: String, _ language: String = "en-US", quality: Int = 0, novelty: Bool = false, personal: Bool = false) -> VoiceRanking.Candidate {
        VoiceRanking.Candidate(identifier: id, language: language, qualityRank: quality, isNovelty: novelty, isPersonal: personal)
    }

    @Test func premiumBeatsEnhancedBeatsDefault() {
        let voices = [voice("basic"), voice("premium", quality: 2), voice("enhanced", quality: 1)]
        #expect(VoiceRanking.best(from: voices, language: "en-US", systemDefault: "basic") == "premium")
    }

    @Test func prefersThePhonesOwnRegionAtEqualQuality() {
        let voices = [voice("british", "en-GB", quality: 2), voice("american", "en-US", quality: 2)]
        #expect(VoiceRanking.best(from: voices, language: "en-US", systemDefault: nil) == "american")
        #expect(VoiceRanking.best(from: [voice("british", "en-GB", quality: 2), voice("american", quality: 1)],
                                  language: "en-US", systemDefault: nil) == "british", "quality comes first")
    }

    @Test func fallsBackToTheSystemDefaultAmongBasicVoices() {
        let voices = [voice("a"), voice("samantha"), voice("z")]
        #expect(VoiceRanking.best(from: voices, language: "en-US", systemDefault: "samantha") == "samantha")
    }

    @Test func neverPicksNoveltyPersonalOrOtherLanguages() {
        let voices = [voice("bells", quality: 2, novelty: true), voice("me", quality: 2, personal: true),
                      voice("french", "fr-FR", quality: 2), voice("plain")]
        #expect(VoiceRanking.best(from: voices, language: "en-US", systemDefault: nil) == "plain")
        #expect(VoiceRanking.best(from: [voice("french", "fr-FR")], language: "en-US", systemDefault: nil) == nil)
    }

    @Test func languageCodesCompareByLanguage() {
        #expect(VoiceRanking.baseLanguage("en-US") == "en")
        #expect(VoiceRanking.baseLanguage("en_GB") == "en")
        #expect(VoiceRanking.baseLanguage("fr") == "fr")
    }
}
