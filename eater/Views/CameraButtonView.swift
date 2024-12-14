import AVFoundation
import SwiftUI

struct CameraButtonView: View {
    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false

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
            CameraView(photoType: "default_prompt", onPhotoSubmitted: {
                onPhotoSubmitted?()
                showCamera = false
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
    var photoType: String
    var onPhotoSubmitted: (() -> Void)?

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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let grpcService = GRPCService()
                grpcService.sendPhoto(image: image, photoType: parent.photoType) { success in
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

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
