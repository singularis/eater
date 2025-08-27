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
            
            // Show loading overlay on top of picker instead of dismissing immediately
            showLoadingOverlay(on: picker)

            GRPCService().sendPhoto(image: image, photoType: "weight_prompt") { [weak self] success in
                DispatchQueue.main.async {
                    // Dismiss picker after processing is complete
                    picker.dismiss(animated: true)
                    
                    if success {
                        // Clear today's statistics cache since weight was updated
                        StatisticsService.shared.clearExpiredCache()
                        self?.parent.onPhotoSuccess?()
                    } else {
                        self?.parent.onPhotoFailure?()
                    }
                }
            }
        }
        
        private func showLoadingOverlay(on picker: UIImagePickerController) {
            let overlay = UIView(frame: picker.view.bounds)
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            overlay.tag = 999 // For easy removal later
            
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.color = .white
            activityIndicator.center = overlay.center
            activityIndicator.startAnimating()
            
            let label = UILabel()
            label.text = loc("loading.scale", "Reading weight scale...")
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: activityIndicator.center.y + 40, width: overlay.bounds.width, height: 30)
            
            overlay.addSubview(activityIndicator)
            overlay.addSubview(label)
            picker.view.addSubview(overlay)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
} 