import SwiftUI

/// Shown once, the first time Passing opens (2.0), and again from Settings → How Passing Works.
/// Three short pages: what a tap does, why Passing asks for location, and the hands-free ways to
/// pin. It's for reading while parked, before the first drive; it never appears over the capture
/// screen for someone who has already set Passing up.
struct WelcomeView: View {
    /// Called by the last page's button (and by Skip).
    var done: () -> Void

    @State private var page = 0
    private let location = LocationProvider.shared
    private static let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: done)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(page < Self.pageCount - 1 ? 1 : 0)
                    .disabled(page == Self.pageCount - 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $page) {
                tapPage.tag(0)
                locationPage.tag(1)
                handsFreePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: next) {
                Text(buttonTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.captureBackground)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.pinYellow, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.captureBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    private var buttonTitle: String {
        switch page {
        case 1 where location.authorization == .notDetermined: return "Allow Location"
        case Self.pageCount - 1: return "Start"
        default: return "Next"
        }
    }

    private func next() {
        if page == 1, location.authorization == .notDetermined {
            // iOS shows its own question; whatever the answer, Next moves on.
            location.requestPermissionIfNeeded()
            return
        }
        if page < Self.pageCount - 1 {
            withAnimation { page += 1 }
        } else {
            done()
        }
    }

    private var tapPage: some View {
        WelcomePage(title: "See it. Tap once.") {
            PinGlyph()
                .frame(width: 96, height: 96)
        } text: {
            Text("Passing saves where you are with one tap, so you can look up what you passed later, once you're parked.")
            Text("A buzz and a short tone say it's saved. There's nothing to read, type or answer.")
        }
    }

    private var locationPage: some View {
        WelcomePage(title: "Your location, only when you pin") {
            Image(systemName: "location.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Color.pinYellow)
        } text: {
            Text("Passing uses your location while it's open, and for a few seconds when you pin from Siri or a widget. It never tracks you in the background.")
            Text("Your pins stay on this iPhone. No account, no ads.")
            Text(locationNote)
                .foregroundStyle(Color.pinYellow)
        }
    }

    private var locationNote: String {
        if location.isDenied {
            return "Location is off for Passing. Pins still save, with the time only. You can turn it on in iOS Settings."
        }
        if location.isAuthorized {
            return "Location is on."
        }
        return "Choose Allow While Using App when iOS asks."
    }

    private var handsFreePage: some View {
        WelcomePage(title: "Hands-free ways to pin") {
            Image(systemName: "steeringwheel")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Color.pinYellow)
        } text: {
            Text("Say **“Hey Siri, pin that in Passing.”**")
            Text("Add a **Passing widget** to your Home Screen. In a car with a CarPlay touchscreen, it shows there too.")
            Text("Later, open **Pins** to see each one on a map and find out what it was.")
            Text("Set things up while parked, and keep your eyes on the road.")
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// One page: a picture, a title and a few short lines.
private struct WelcomePage<Picture: View, Lines: View>: View {
    let title: String
    @ViewBuilder let picture: () -> Picture
    @ViewBuilder let text: () -> Lines

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                picture()
                    .padding(.top, 36)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 14) {
                    text()
                }
                .font(.system(.title3, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
        }
    }
}

#Preview {
    WelcomeView(done: {})
}
