import SwiftData
import SwiftUI

/// Make, rename and delete groups. Deleting a group keeps its pins.
struct GroupsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PinGroup.name) private var groups: [PinGroup]
    @State private var newName = ""
    @State private var renaming: PinGroup?
    @State private var renameText = ""
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New group, e.g. Road trip", text: $newName)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } footer: {
                    if let problem {
                        Text(problem)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if groups.isEmpty {
                        Text("No groups yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(groups) { group in
                        Button {
                            problem = nil
                            renameText = group.name
                            renaming = group
                        } label: {
                            LabeledContent(group.name) {
                                Text("\(activePinCount(group))")
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { groups[$0] }
                        for group in doomed {
                            PinGroups.delete(group, in: context)
                        }
                    }
                } footer: {
                    Text("Tap a group to rename it. Swipe left to delete one; its pins stay in your list.")
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Group", isPresented: renamingShown) {
                TextField("Name", text: $renameText)
                Button("Save") { saveRename() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var renamingShown: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    /// Pins in Recently Deleted keep their group (so recovering one puts it back) but aren't counted.
    private func activePinCount(_ group: PinGroup) -> Int {
        group.pins.filter { $0.deletedAt == nil }.count
    }

    private func add() {
        if PinGroups.create(named: newName, in: context) != nil {
            newName = ""
            problem = nil
        } else {
            problem = nameProblem(newName)
        }
    }

    private func saveRename() {
        guard let group = renaming else { return }
        if !PinGroups.rename(group, to: renameText, in: context) {
            problem = nameProblem(renameText)
        }
        renaming = nil
    }

    private func nameProblem(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "A group needs a name." : "There's already a group called “\(trimmed)”."
    }
}
