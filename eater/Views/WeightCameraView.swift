import AVFoundation
import SwiftUI

struct WeightCameraView: UIViewControllerRepresentable {
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
        return Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: WeightCameraView
        
        init(_ parent: WeightCameraView) { 
            self.parent = parent 
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { self.parent.onPhotoFailure?() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { self.parent.onPhotoStarted?() }

            GRPCService().sendPhoto(image: image, photoType: "weight_prompt") { [weak self] success in
                DispatchQueue.main.async {
                    picker.dismiss(animated: true)
                    
                    if success {
                        self?.parent.onPhotoSuccess?()
                    } else {
                        self?.parent.onPhotoFailure?()
                    }
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
} 