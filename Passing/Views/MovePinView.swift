import MapKit
import SwiftUI

/// Drag the map until the crosshair is on the thing you passed, then Save. Where your car was stays
/// as recorded; this sets the pin's spot, which map links, Look Around, the town and exports use.
/// Only reachable from Pins, so it's for when you're parked.
struct MovePinView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    /// The point under the crosshair. Nil until the map has shown somewhere.
    @State private var center: CLLocationCoordinate2D?
    @State private var satellite = true

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                if let car = pin.captureCoordinate {
                    Marker("Your car", systemImage: "car.fill", coordinate: car)
                        .tint(.blue)
                }
            }
            // Satellite by default: barns, signs and buildings are easier to find from above.
            .mapStyle(satellite ? .hybrid : .standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.camera.centerCoordinate
            }
            .overlay {
                Image(systemName: "scope")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.orange)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Text("Drag the map so the orange crosshair is on what you passed.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    HStack {
                        if let car = pin.captureCoordinate {
                            Button("Where my car was") {
                                withAnimation { position = Self.region(around: car) }
                            }
                        }
                        Spacer()
                        Button(satellite ? "Map" : "Satellite") {
                            satellite.toggle()
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle(pin.lookUpCoordinate == nil ? "Place Pin" : "Move Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let center {
                            pin.moveTarget(to: center)
                            try? pin.modelContext?.save()
                        }
                        dismiss()
                    }
                    .disabled(center == nil)
                }
            }
            .onAppear {
                // Start on the pin's current spot; a pin with no location starts where you are now.
                if let start = pin.lookUpCoordinate {
                    position = Self.region(around: start)
                } else {
                    position = .userLocation(fallback: .automatic)
                }
            }
        }
    }

    private static func region(around coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500))
    }
}
