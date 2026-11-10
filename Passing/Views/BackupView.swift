import SwiftUI
import UniformTypeIdentifiers

/// Settings → Back Up and Restore (2.0): one file with every pin, and a way to read it back in.
/// Pins live only on this iPhone, so this is how to keep a copy somewhere else or move to a new phone
/// without a full iPhone backup.
struct BackupView: View {
    @State private var shareFile: ExportFile?
    @State private var choosingFile = false
    @State private var message: String?
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                Button {
                    backUp()
                } label: {
                    Label("Back Up All Pins…", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Makes one file with every pin and note in Pins: names, notes, groups, places and photos. Save it to Files or iCloud Drive, or send it to yourself. It isn't locked, and it holds where your pins are, so keep it somewhere private. Recently Deleted and speeds aren't included.")
            }

            Section {
                Button {
                    choosingFile = true
                } label: {
                    Label("Restore from a Backup…", systemImage: "square.and.arrow.down")
                }
                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Adds the pins from a backup file that aren't here already. Nothing here is changed or replaced, so restoring the same file twice adds nothing. Pins older than 7 days come back kept (starred), so they don't expire straight away.")
            }
        }
        .navigationTitle("Back Up and Restore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url]) { _ in
                ExportService.removeExportedFiles()
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
            restore(result)
        }
        .alert("That didn't work", isPresented: problemShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
    }

    private var problemShown: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }

    private func backUp() {
        do {
            let url = try BackupService.makeBackupFile(context: SharedStore.context, retention: .shared)
            shareFile = ExportFile(url: url)
        } catch {
            problem = "Passing couldn't make the backup file. \(error.localizedDescription)"
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        message = nil
        do {
            let outcome = try BackupService.restore(from: try result.get(), context: SharedStore.context)
            message = PinBackup.restoreMessage(added: outcome.added, alreadyHere: outcome.alreadyHere)
        } catch PinBackup.ReadError.notABackup {
            problem = "That file isn't a Passing backup. Backups are named “Passing backup” with a date. (The JSON, CSV and KML exports from Pins are for other apps and can't be restored.)"
        } catch PinBackup.ReadError.newerVersion {
            problem = "That backup was made by a newer version of Passing. Update Passing, then try again."
        } catch {
            problem = "Passing couldn't read that file. \(error.localizedDescription)"
        }
    }
}
