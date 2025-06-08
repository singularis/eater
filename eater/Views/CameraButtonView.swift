import AVFoundation
import SwiftUI

struct CameraButtonView: View {
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var cameraUnavailableAlert = false
    @State private var photoLibraryUnavailableAlert = false

    let isLoadingFoodPhoto: Bool
    var onPhotoSuccess: (() -> Void)?
    var onPhotoFailure: (() -> Void)?
    var onPhotoStarted: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            let totalWidth  = geo.size.width
            let uploadWidth = totalWidth * 0.30
            let gapWidth    = totalWidth * 0.05
            let takeWidth   = totalWidth - uploadWidth - gapWidth

            HStack(spacing: 0) {
                Button(action: {
                    if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                        showPhotoLibrary = true
                    } else {
                        photoLibraryUnavailableAlert = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 18))
                        Text("Upload")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 24)
                    .frame(width: uploadWidth)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingFoodPhoto)

                Color.clear
                    .frame(width: gapWidth)

                Button(action: {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        cameraUnavailableAlert = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                        Text("Take Food Photo")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 24)
                    .frame(width: takeWidth)
                    .background(Color.green)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingFoodPhoto)
            }
            .frame(height: 100)
        }
        .frame(height: 100)

        .sheet(isPresented: $showCamera) {
            CameraView(
                photoType: "default_prompt",
                onPhotoSuccess: { onPhotoSuccess?() },
                onPhotoFailure: { onPhotoFailure?() },
                onPhotoStarted: { onPhotoStarted?() }
            )
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryView(
                photoType: "default_prompt",
                onPhotoSuccess: { onPhotoSuccess?() },
                onPhotoFailure: { onPhotoFailure?() },
                onPhotoStarted: { onPhotoStarted?() }
            )
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Your device does not have a camera.")
        }
        .alert("Photo Library Unavailable", isPresented: $photoLibraryUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Photo library is not available.")
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    var photoType: String
    var onPhotoSuccess: (() -> Void)?
    var onPhotoFailure: (() -> Void)?
    var onPhotoStarted: (() -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { self.parent.onPhotoFailure?() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { self.parent.onPhotoStarted?() }

            GRPCService().sendPhoto(image: image, photoType: parent.photoType) { success in
                DispatchQueue.main.async {
                    success ? self.parent.onPhotoSuccess?() : self.parent.onPhotoFailure?()
                }
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Library View
struct PhotoLibraryView: UIViewControllerRepresentable {
    var photoType: String
    var onPhotoSuccess: (() -> Void)?
    var onPhotoFailure: (() -> Void)?
    var onPhotoStarted: (() -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: PhotoLibraryView
        init(_ parent: PhotoLibraryView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { self.parent.onPhotoFailure?() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { self.parent.onPhotoStarted?() }

            GRPCService().sendPhoto(image: image, photoType: parent.photoType) { success in
                DispatchQueue.main.async {
                    success ? self.parent.onPhotoSuccess?() : self.parent.onPhotoFailure?()
                }
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
