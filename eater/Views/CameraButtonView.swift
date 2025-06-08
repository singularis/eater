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
        var temporaryTimestamp: Int64?
        
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { self.parent.onPhotoFailure?() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { self.parent.onPhotoStarted?() }
            
            // Show loading overlay on top of picker instead of dismissing
            showLoadingOverlay(on: picker)

            let currentTimeMillis = Int64(Date().timeIntervalSince1970 * 1000)
            self.temporaryTimestamp = currentTimeMillis
            
            let imageSaved = ImageStorageService.shared.saveTemporaryImage(image, forTime: currentTimeMillis)
            if !imageSaved {
                print("Warning: Failed to save temporary image locally")
            }

            GRPCService().sendPhoto(image: image, photoType: parent.photoType, timestampMillis: currentTimeMillis) { [weak self] success in
                print("CameraView coordinator: GRPCService callback received with success=\(success)")
                print("CameraView coordinator: self is \(self != nil ? "not nil" : "nil")")
                
                DispatchQueue.main.async {
                    print("CameraView coordinator: On main queue, about to handle result")
                    
                    // Dismiss picker now that processing is complete
                    picker.dismiss(animated: true)
                    
                    if success {
                        print("CameraView coordinator: Success=true, calling handlePhotoSuccess")
                        self?.handlePhotoSuccess()
                    } else {
                        print("CameraView coordinator: Success=false, calling handlePhotoFailure")
                        self?.handlePhotoFailure()
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
            label.text = "Analyzing food photo..."
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: activityIndicator.center.y + 40, width: overlay.bounds.width, height: 30)
            
            overlay.addSubview(activityIndicator)
            overlay.addSubview(label)
            picker.view.addSubview(overlay)
        }
        
        private func handlePhotoSuccess() {
            print("CameraView handlePhotoSuccess: Method called")
            
            guard let tempTimestamp = temporaryTimestamp else {
                print("CameraView handlePhotoSuccess: No tempTimestamp, calling onPhotoFailure")
                parent.onPhotoFailure?()
                return
            }
            
            print("CameraView handlePhotoSuccess: About to call original success callback")
            
            // Call the original success callback immediately
            parent.onPhotoSuccess?()
            
            print("CameraView handlePhotoSuccess: Original success callback called")
            
            // Wait a moment for the UI update, then do image mapping
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("CameraView handlePhotoSuccess: Starting image mapping process...")
                
                // Fetch latest products to get the backend timestamp
                GRPCService().fetchProducts { products, _, _ in
                    DispatchQueue.main.async {
                        // Find the newest product (highest timestamp)
                        if let newestProduct = products.max(by: { $0.time < $1.time }) {
                            print("CameraView handlePhotoSuccess: Found newest product with time: \(newestProduct.time)")
                            
                            // Move temporary image to final location
                            let moved = ImageStorageService.shared.moveTemporaryImage(
                                fromTime: tempTimestamp,
                                toTime: newestProduct.time
                            )
                            
                            if moved {
                                print("Successfully mapped image from temp_\(tempTimestamp) to \(newestProduct.time)")
                            } else {
                                print("Failed to map image, deleting temporary image")
                                ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                            }
                        } else {
                            print("No products found, deleting temporary image")
                            ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                        }
                        
                        self?.temporaryTimestamp = nil
                    }
                }
            }
        }
        
        private func handlePhotoFailure() {
            if let tempTimestamp = temporaryTimestamp {
                ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                temporaryTimestamp = nil
            }
            parent.onPhotoFailure?()
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
        var temporaryTimestamp: Int64?
        
        init(_ parent: PhotoLibraryView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { self.parent.onPhotoFailure?() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { self.parent.onPhotoStarted?() }
            
            // Show loading overlay on top of picker instead of dismissing
            showLoadingOverlay(on: picker)

            let currentTimeMillis = Int64(Date().timeIntervalSince1970 * 1000)
            self.temporaryTimestamp = currentTimeMillis
            
            let imageSaved = ImageStorageService.shared.saveTemporaryImage(image, forTime: currentTimeMillis)
            if !imageSaved {
                print("Warning: Failed to save temporary image locally")
            }

            GRPCService().sendPhoto(image: image, photoType: parent.photoType, timestampMillis: currentTimeMillis) { [weak self] success in
                print("PhotoLibraryView coordinator: GRPCService callback received with success=\(success)")
                print("PhotoLibraryView coordinator: self is \(self != nil ? "not nil" : "nil")")
                
                DispatchQueue.main.async {
                    print("PhotoLibraryView coordinator: On main queue, about to handle result")
                    
                    // Dismiss picker now that processing is complete
                    picker.dismiss(animated: true)
                    
                    if success {
                        print("PhotoLibraryView coordinator: Success=true, calling handlePhotoSuccess")
                        self?.handlePhotoSuccess()
                    } else {
                        print("PhotoLibraryView coordinator: Success=false, calling handlePhotoFailure")
                        self?.handlePhotoFailure()
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
            label.text = "Analyzing food photo..."
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: activityIndicator.center.y + 40, width: overlay.bounds.width, height: 30)
            
            overlay.addSubview(activityIndicator)
            overlay.addSubview(label)
            picker.view.addSubview(overlay)
        }
        
        private func handlePhotoSuccess() {
            print("PhotoLibraryView handlePhotoSuccess: Method called")
            
            guard let tempTimestamp = temporaryTimestamp else {
                print("PhotoLibraryView handlePhotoSuccess: No tempTimestamp, calling onPhotoFailure")
                parent.onPhotoFailure?()
                return
            }
            
            print("PhotoLibraryView handlePhotoSuccess: About to call original success callback")
            
            // Call the original success callback immediately
            parent.onPhotoSuccess?()
            
            print("PhotoLibraryView handlePhotoSuccess: Original success callback called")
            
            // Wait a moment for the UI update, then do image mapping
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("PhotoLibraryView handlePhotoSuccess: Starting image mapping process...")
                
                // Fetch latest products to get the backend timestamp
                GRPCService().fetchProducts { products, _, _ in
                    DispatchQueue.main.async {
                        // Find the newest product (highest timestamp)
                        if let newestProduct = products.max(by: { $0.time < $1.time }) {
                            print("PhotoLibraryView handlePhotoSuccess: Found newest product with time: \(newestProduct.time)")
                            
                            // Move temporary image to final location
                            let moved = ImageStorageService.shared.moveTemporaryImage(
                                fromTime: tempTimestamp,
                                toTime: newestProduct.time
                            )
                            
                            if moved {
                                print("Successfully mapped image from temp_\(tempTimestamp) to \(newestProduct.time)")
                            } else {
                                print("Failed to map image, deleting temporary image")
                                ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                            }
                        } else {
                            print("No products found, deleting temporary image")
                            ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                        }
                        
                        self?.temporaryTimestamp = nil
                    }
                }
            }
        }
        
        private func handlePhotoFailure() {
            if let tempTimestamp = temporaryTimestamp {
                ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                temporaryTimestamp = nil
            }
            parent.onPhotoFailure?()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
