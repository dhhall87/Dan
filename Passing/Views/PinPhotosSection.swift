import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// The pin screen's Photos: a row of thumbnails, **Take Photo** (the camera) and **Choose Photo**
/// (the library, which needs no permission). Only ever while reviewing, never on the capture
/// screen. Tapping a photo opens it full screen, where it can be deleted.
struct PinPhotosSection: View {
    let pin: Pin
    @Environment(\.modelContext) private var context
    @State private var picked: [PhotosPickerItem] = []
    @State private var takingPhoto = false
    /// Photos still being made smaller, so the row shows a spinner and the limit counts them.
    @State private var adding = 0
    @State private var viewing: PhotoSelection?
    @State private var problem: String?
    @State private var cameraOff = false

    var body: some View {
        Section {
            rows
        } header: {
            Text("Photos")
        } footer: {
            Text(footer)
        }
        .onChange(of: picked) {
            addPicked()
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in
                addTaken(image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewing) { selection in
            PhotoViewer(pin: pin, startAt: selection.id)
        }
        .alert("Camera is off for Passing", isPresented: $cameraOff) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To take photos for your pins, turn on Camera for Passing in Settings.")
        }
        .alert("Photo not saved", isPresented: problemShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
    }

    @ViewBuilder
    private var rows: some View {
        let photos = PinPhotos.sorted(pin)
        if !photos.isEmpty || adding > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        Button {
                            viewing = PhotoSelection(id: photo.id)
                        } label: {
                            PhotoThumbnail(photo: photo)
                        }
                        .buttonStyle(.plain)
                    }
                    if adding > 0 {
                        ProgressView()
                            .frame(width: 72, height: 72)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        if CameraPicker.isAvailable {
            Button {
                takePhoto()
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            .disabled(room == 0)
        }
        PhotosPicker(selection: $picked, maxSelectionCount: max(room, 1), matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
        }
        .disabled(room == 0)
    }

    /// How many more photos fit, counting ones still being added.
    private var room: Int {
        max(0, PinPhotos.remaining(for: pin) - adding)
    }

    private var footer: String {
        if room == 0, adding == 0 {
            return "This pin has \(PinPhotos.maxPerPin) photos, the most it keeps. Delete one to add another."
        }
        return "Passing keeps a smaller copy of each photo on this iPhone, without the photo's location. Photos aren't in exports, and they're deleted with the pin."
    }

    private var problemShown: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }

    private func takePhoto() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            takingPhoto = true
        case .notDetermined:
            // iOS asks once, here; saying no just leaves things as they were.
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    takingPhoto = true
                }
            }
        default:
            cameraOff = true
        }
    }

    private func addTaken(_ image: UIImage) {
        adding += 1
        Task {
            let prepared = await PinPhotos.prepare(image)
            finish(prepared)
        }
    }

    private func addPicked() {
        let items = picked
        guard !items.isEmpty else { return }
        picked = []
        adding += items.count
        Task {
            for item in items {
                var prepared: PinPhotos.Prepared?
                if let data = try? await item.loadTransferable(type: Data.self) {
                    prepared = await PinPhotos.prepare(data)
                }
                finish(prepared)
            }
        }
    }

    /// Saves a prepared photo, or says why not.
    private func finish(_ prepared: PinPhotos.Prepared?) {
        adding = max(0, adding - 1)
        // The pin may have been deleted while the photo was being made smaller; reading a pin
        // that's gone crashes.
        guard pin.modelContext != nil, !pin.isDeleted else { return }
        guard let prepared else {
            problem = "Passing couldn't read that photo."
            return
        }
        if !PinPhotos.add(prepared, to: pin, in: context) {
            problem = PinPhotos.remaining(for: pin) == 0
                ? "This pin already has \(PinPhotos.maxPerPin) photos."
                : "It couldn't be written to the iPhone's storage. Try again; if it keeps happening, close and reopen Passing."
        }
    }
}

private struct PhotoSelection: Identifiable {
    let id: UUID
}

private struct PhotoThumbnail: View {
    let photo: PinPhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.tertiarySystemFill)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityLabel("Photo")
        .task(id: photo.id) {
            guard photo.modelContext != nil, !photo.isDeleted else { return }
            image = photo.thumbnailData.flatMap(UIImage.init(data:))
        }
    }
}

/// One pin's photos, full screen: swipe between them; Delete removes the one showing.
private struct PhotoViewer: View {
    let pin: Pin
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var current: UUID
    @State private var confirmingDelete = false

    init(pin: Pin, startAt id: UUID) {
        self.pin = pin
        _current = State(initialValue: id)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $current) {
                ForEach(photos) { photo in
                    FullPhoto(photo: photo)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Photo", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Photo", role: .destructive) {
                    deleteCurrent()
                }
            } message: {
                Text("It's deleted for good. The pin stays.")
            }
        }
    }

    private var photos: [PinPhoto] {
        guard pin.modelContext != nil, !pin.isDeleted else { return [] }
        return PinPhotos.sorted(pin)
    }

    private func deleteCurrent() {
        let before = photos
        guard let index = before.firstIndex(where: { $0.id == current }) else { return }
        PinPhotos.delete(before[index], in: context)
        let after = photos
        if after.isEmpty {
            dismiss()
        } else {
            current = after[min(index, after.count - 1)].id
        }
    }
}

private struct FullPhoto: View {
    let photo: PinPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: photo.id) {
            guard photo.modelContext != nil, !photo.isDeleted else { return }
            image = photo.imageData.flatMap(UIImage.init(data:))
        }
    }
}

/// The system camera, for Take Photo. The Simulator has none, so the button is hidden there.
struct CameraPicker: UIViewControllerRepresentable {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPhoto(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
