import SwiftUI
import AVFoundation

struct CameraButtonView: View {
    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false

    // Closure to notify when photo is submitted
    var onPhotoSubmitted: (() -> Void)?

    var body: some View {
        Button(action: {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCamera = true
            } else {
                cameraUnavailableAlert = true
            }
        }) {
            Image(systemName: "camera.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding()
        }
        .sheet(isPresented: $showCamera) {
            // Pass the closure to CameraView
            CameraView(onPhotoSubmitted: {
                onPhotoSubmitted?() // Call the closure when photo is submitted
                showCamera = false  // Dismiss the sheet
            })
        }
        .alert(isPresented: $cameraUnavailableAlert) {
            Alert(
                title: Text("Camera Unavailable"),
                message: Text("Your device does not have a camera."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    // Closure to notify when photo is submitted
    var onPhotoSubmitted: (() -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera // Force camera usage
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"] // Allow photos only
        picker.allowsEditing = false // Disable editing if not required
        picker.modalPresentationStyle = .fullScreen // Ensure full-screen presentation
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        // Called when the user picks an image
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Send the photo via GRPCService
                let grpcService = GRPCService()
                grpcService.sendPhoto(image: image) { success in
                    if success {
                        print("Photo sent successfully!")
                    } else {
                        print("Failed to send photo.")
                    }
                }
                parent.onPhotoSubmitted?()
            }
            picker.dismiss(animated: true)
        }

        // Called when the user cancels the picker
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
