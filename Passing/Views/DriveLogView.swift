import SwiftUI

/// Settings → Drive Log: the summary of how Passing did on real drives, the latest events, and a
/// text file to share (with yourself, or with whoever's helping tune the app).
struct DriveLogView: View {
    @AppStorage(DriveLog.enabledKey, store: AppGroup.defaults) private var isOn = false
    @State private var entries: [DriveLogEntry] = []
    @State private var shareFile: ExportFile?
    @State private var exportError: String?
    @State private var confirmingClear = false

    /// Enough to see the last drive or two at a glance; the shared file has everything.
    private static let shownEvents = 100

    var body: some View {
        List {
            Section {
                Toggle("Keep a drive log", isOn: $isOn)
            } footer: {
                Text("Records how each pin went (how long GPS took, how accurate it was, whether it saved), how long GPS ran, and when the miles-back trail restarted. It never records where you were, labels, notes or speeds, and it stays on this iPhone until you share it. Turning it off keeps what's there; Clear deletes it.")
            }

            Section("Summary") {
                ForEach(Array(DriveLogSummary.lines(for: entries).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(line.hasPrefix("  ") ? .footnote : .subheadline)
                        .foregroundStyle(line.hasPrefix("  ") ? .secondary : .primary)
                }
            }

            if !entries.isEmpty {
                Section {
                    ForEach(Array(entries.suffix(Self.shownEvents).reversed().enumerated()), id: \.offset) { _, entry in
                        Text(entry.line())
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Latest events")
                } footer: {
                    Text(entries.count > Self.shownEvents ? "Showing the newest \(Self.shownEvents) of \(entries.count). Share has them all." : "Newest first.")
                }
            }
        }
        .navigationTitle("Drive Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    share()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(entries.isEmpty)
            }
        }
        .confirmationDialog("Clear the drive log?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear Drive Log", role: .destructive) {
                DriveLog.clear()
                entries = []
            }
        } message: {
            Text("Deletes every event. Pins aren't affected.")
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url]) { _ in
                ExportService.removeExportedFiles()
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
        .alert("Couldn't make the file", isPresented: exportErrorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .task {
            entries = await DriveLog.load()
        }
        .refreshable {
            entries = await DriveLog.load()
        }
    }

    private var exportErrorShown: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private func share() {
        Task {
            do {
                let url = try await DriveLog.exportFile()
                shareFile = ExportFile(url: url)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}
