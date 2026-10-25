import SwiftData
import SwiftUI

/// Make, rename and delete groups. Deleting a group keeps its pins.
struct GroupsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PinGroup.name) private var groups: [PinGroup]
    @State private var addingGroup = false
    @State private var renaming: PinGroup?
    @State private var renameText = ""
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        problem = nil
                        addingGroup = true
                    } label: {
                        Label("New Group…", systemImage: "folder.badge.plus")
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
                    Text("Tap a group to rename or delete it, or swipe left (or tap Edit) to delete. Deleting a group keeps its pins.")
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Shows a delete button on every group, for anyone who doesn't know to swipe.
                    EditButton()
                        .disabled(groups.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .newGroupAlert(isPresented: $addingGroup)
            .alert("Rename Group", isPresented: renamingShown) {
                TextField("Name", text: $renameText)
                Button("Save") { saveRename() }
                Button("Delete Group", role: .destructive) {
                    if let group = renaming {
                        PinGroups.delete(group, in: context)
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deleting a group keeps its pins.")
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

/// The "New Group" name prompt, used wherever a group can be made: the Pins list's folder menu,
/// a pin's long-press menu, Select mode, a pin's screen and Manage Groups. If the name is already
/// taken, that group is used instead of making a second one.
private struct NewGroupAlert: ViewModifier {
    @Binding var isPresented: Bool
    let message: String?
    let onCreate: (PinGroup) -> Void
    @Environment(\.modelContext) private var context
    @State private var name = ""

    func body(content: Content) -> some View {
        content.alert("New Group", isPresented: $isPresented) {
            TextField("Name, e.g. Road trip", text: $name)
            Button("Create") {
                if let group = PinGroups.createOrFind(named: name, in: context) {
                    onCreate(group)
                }
                name = ""
            }
            Button("Cancel", role: .cancel) {
                name = ""
            }
        } message: {
            if let message {
                Text(message)
            }
        }
    }
}

extension View {
    /// Shows the "New Group" prompt. `onCreate` gets the new (or same-named existing) group.
    func newGroupAlert(isPresented: Binding<Bool>, message: String? = nil, onCreate: @escaping (PinGroup) -> Void = { _ in }) -> some View {
        modifier(NewGroupAlert(isPresented: isPresented, message: message, onCreate: onCreate))
    }
}
