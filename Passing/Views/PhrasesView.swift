import SwiftUI

/// Your own spoken confirmations ("Got it boss", "I'll look this up later"). One is picked at
/// random after each pin.
struct PhrasesView: View {
    @AppStorage(SettingsKey.confirmationPhrases) private var stored = SpokenConfirmation.defaultPhrase
    @AppStorage(SettingsKey.sayClueFirst) private var sayClueFirst = true
    @State private var newPhrase = ""

    private var phrases: [String] {
        SpokenConfirmation.phrases(from: stored)
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(phrases.enumerated()), id: \.offset) { _, phrase in
                    HStack {
                        Text(phrase)
                        Spacer(minLength: 0)
                        Button {
                            CaptureFeedback.shared.preview(sample(for: phrase))
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Preview \(phrase)")
                    }
                }
                .onDelete { offsets in
                    var list = phrases
                    list.remove(atOffsets: offsets)
                    stored = SpokenConfirmation.stored(list)
                }
            } header: {
                Text("One is picked at random each time")
            } footer: {
                if phrases.isEmpty {
                    Text("With no phrases, Passing says “\(SpokenConfirmation.defaultPhrase)”.")
                } else {
                    Text("Swipe left on a phrase to remove it.")
                }
            }

            Section {
                TextField("Add a phrase, like Got it boss", text: $newPhrase)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .onChange(of: newPhrase) { _, value in
                        if value.count > SpokenConfirmation.maxPhraseLength {
                            newPhrase = String(value.prefix(SpokenConfirmation.maxPhraseLength))
                        }
                    }
                HStack {
                    Text("\(newPhrase.count)/\(SpokenConfirmation.maxPhraseLength)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add", action: add)
                        .disabled(SpokenConfirmation.clean(newPhrase).isEmpty)
                }
            } footer: {
                Text("Keep it short so confirmations stay quick. “+1 mi back” always says the distance instead, like “2 miles back”.")
            }
        }
        .navigationTitle("Phrases")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// How the phrase will actually sound after a far-left pin.
    private func sample(for phrase: String) -> String {
        SpokenConfirmation.text(side: .left, distance: .far, milesBack: 0, phrases: [phrase], sayClueFirst: sayClueFirst)
    }

    private func add() {
        let phrase = SpokenConfirmation.clean(newPhrase)
        guard !phrase.isEmpty else { return }
        stored = SpokenConfirmation.stored(phrases + [phrase])
        newPhrase = ""
    }
}
