import AVFoundation
import SwiftUI

struct CameraButtonView: View {
    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false

    let isLoadingFoodPhoto: Bool
    var onPhotoSuccess: (() -> Void)?
    var onPhotoFailure: (() -> Void)?
    var onPhotoStarted: (() -> Void)?

    var body: some View {
        Button(action: {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCamera = true
            } else {
                cameraUnavailableAlert = true
            }
        }) {
            HStack {
                if isLoadingFoodPhoto {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                } else {
                    Image(systemName: "camera.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Add Food")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }
            .padding()
        }
        .disabled(isLoadingFoodPhoto)
        .sheet(isPresented: $showCamera) {
            CameraView(
                photoType: "default_prompt", 
                onPhotoSuccess: {
                    onPhotoSuccess?()
                },
                onPhotoFailure: {
                    onPhotoFailure?()
                },
                onPhotoStarted: {
                    onPhotoStarted?()
                }
            )
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
                DispatchQueue.main.async {
                    self.parent.onPhotoStarted?()
                }
                
                let grpcService = GRPCService()
                grpcService.sendPhoto(image: image, photoType: parent.photoType) { success in
                    DispatchQueue.main.async {
                        if success {
                            print("Photo sent successfully!")
                            self.parent.onPhotoSuccess?()
                        } else {
                            print("Failed to send photo.")
                            self.parent.onPhotoFailure?()
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.parent.onPhotoFailure?()
                }
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
