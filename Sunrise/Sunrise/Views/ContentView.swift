import SwiftUI

struct ContentView: View {
    @Environment(SunriseModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Wake gently, on your schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if model.home.access == .allowed, model.selectedHome != nil {
                        SunriseCards()
                    } else {
                        ConnectCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(SunriseBackground())
            .navigationTitle("Sunrise")
        }
        .fontDesign(.rounded)
        .overlay {
            if let progress = model.savingProgress {
                SavingOverlay(done: progress.done, total: progress.total)
            }
        }
        .task {
            if model.home.hasConnectedBefore { model.home.connect() }
        }
        .onChange(of: model.settings) { _, settings in
            settings.save()
        }
        .onChange(of: model.home.revision) {
            model.homesLoaded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.home.refresh() }
        }
        .alert(model.problem?.title ?? "", isPresented: problemShown, presenting: model.problem) { _ in
            Button("OK") {}
        } message: { problem in
            Text(problem.message)
        }
    }

    private var problemShown: Binding<Bool> {
        Binding(
            get: { model.problem != nil },
            set: { shown in
                if !shown { model.problem = nil }
            }
        )
    }
}

/// The main screen once Home is connected.
private struct SunriseCards: View {
    @Environment(SunriseModel.self) private var model

    var body: some View {
        @Bindable var model = model
        PreviewCard()
        WakeCard(settings: $model.settings, place: model.location.place)
        LightCard(settings: $model.settings)
        LightsCard()
        HomeCard()
    }
}

private struct SavingOverlay: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                Text("Adding step \(min(done + 1, total)) of \(total) to Home…")
                    .font(.headline)
                Text("Keep Sunrise open until it finishes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(white: 0.12)))
            .padding(40)
        }
    }
}

#Preview {
    ContentView()
        .environment(SunriseModel())
}
