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
    
    init(isLoadingFoodPhoto: Bool, onPhotoSuccess: (() -> Void)?, onPhotoFailure: (() -> Void)?, onPhotoStarted: (() -> Void)?) {
        self.isLoadingFoodPhoto = isLoadingFoodPhoto
        self.onPhotoSuccess = onPhotoSuccess
        self.onPhotoFailure = onPhotoFailure
        self.onPhotoStarted = onPhotoStarted
        
        print("CameraButtonView init: onPhotoSuccess = \(onPhotoSuccess != nil ? "not nil" : "nil")")
    }

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
                        print("CameraButtonView: Camera button tapped, showing camera sheet")
                        print("CameraButtonView: onPhotoSuccess before sheet = \(onPhotoSuccess != nil ? "not nil" : "nil")")
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
            let _ = print("CameraButtonView: Sheet opening, setting callbacks in manager")
            let _ = CameraCallbackManager.shared.setCallbacks(
                onPhotoSuccess: onPhotoSuccess,
                onPhotoFailure: onPhotoFailure,
                onPhotoStarted: onPhotoStarted
            )
            
            return CameraView(photoType: "default_prompt")
        }
        .sheet(isPresented: $showPhotoLibrary) {
            let _ = print("CameraButtonView: Photo library sheet opening, setting callbacks in manager")
            let _ = CameraCallbackManager.shared.setCallbacks(
                onPhotoSuccess: onPhotoSuccess,
                onPhotoFailure: onPhotoFailure,
                onPhotoStarted: onPhotoStarted
            )
            
            return PhotoLibraryView(photoType: "default_prompt")
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

    init(photoType: String) {
        self.photoType = photoType
        print("CameraView init: photoType = \(photoType)")
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        print("CameraView makeUIViewController called")
        
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
        print("CameraView makeCoordinator: Called!")
        
        let coordinator = Coordinator(self)
        print("CameraView makeCoordinator: Coordinator created and returned")
        return coordinator
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraView
        var temporaryTimestamp: Int64?
        
        init(_ parent: CameraView) { 
            print("CameraView Coordinator: Starting init")
            
            self.parent = parent 
            
            super.init()
            
            print("CameraView Coordinator: Init completed")
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { CameraCallbackManager.shared.callPhotoFailure() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { CameraCallbackManager.shared.callPhotoStarted() }
            
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
                CameraCallbackManager.shared.callPhotoFailure()
                return
            }
            
            print("CameraView handlePhotoSuccess: Using ProductStorageService to fetch and map image")
            
            // Use the new unified approach: fetch + map + store + callback
            ProductStorageService.shared.fetchAndProcessProducts(tempImageTime: tempTimestamp) { [weak self] products, calories, weight in
                print("CameraView handlePhotoSuccess: ProductStorageService completed, calling success callback")
                print("CameraView handlePhotoSuccess: About to call CameraCallbackManager.callPhotoSuccess()")
                
                // Call the success callback through the manager
                CameraCallbackManager.shared.callPhotoSuccess()
                
                print("CameraView handlePhotoSuccess: CameraCallbackManager.callPhotoSuccess() called")
                
                self?.temporaryTimestamp = nil
                print("CameraView handlePhotoSuccess: handlePhotoSuccess method completed")
            }
        }
        
        private func handlePhotoFailure() {
            if let tempTimestamp = temporaryTimestamp {
                ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                temporaryTimestamp = nil
            }
            CameraCallbackManager.shared.callPhotoFailure()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Library View
struct PhotoLibraryView: UIViewControllerRepresentable {
    var photoType: String

    init(photoType: String) {
        self.photoType = photoType
        print("PhotoLibraryView init: photoType = \(photoType)")
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        print("PhotoLibraryView makeUIViewController called")
        
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { 
        print("PhotoLibraryView makeCoordinator: Called!")
        
        let coordinator = Coordinator(self)
        print("PhotoLibraryView makeCoordinator: Coordinator created and returned")
        return coordinator
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: PhotoLibraryView
        var temporaryTimestamp: Int64?
        
        init(_ parent: PhotoLibraryView) { 
            print("PhotoLibraryView Coordinator: Starting init")
            
            self.parent = parent 
            
            super.init()
            
            print("PhotoLibraryView Coordinator: Init completed")
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                DispatchQueue.main.async { CameraCallbackManager.shared.callPhotoFailure() }
                picker.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async { CameraCallbackManager.shared.callPhotoStarted() }
            
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
                CameraCallbackManager.shared.callPhotoFailure()
                return
            }
            
            print("PhotoLibraryView handlePhotoSuccess: Using ProductStorageService to fetch and map image")
            
            // Use the new unified approach: fetch + map + store + callback
            ProductStorageService.shared.fetchAndProcessProducts(tempImageTime: tempTimestamp) { [weak self] products, calories, weight in
                print("PhotoLibraryView handlePhotoSuccess: ProductStorageService completed, calling success callback")
                print("PhotoLibraryView handlePhotoSuccess: About to call CameraCallbackManager.callPhotoSuccess()")
                
                // Call the success callback through the manager
                CameraCallbackManager.shared.callPhotoSuccess()
                
                print("PhotoLibraryView handlePhotoSuccess: CameraCallbackManager.callPhotoSuccess() called")
                
                self?.temporaryTimestamp = nil
                print("PhotoLibraryView handlePhotoSuccess: handlePhotoSuccess method completed")
            }
        }
        
        private func handlePhotoFailure() {
            if let tempTimestamp = temporaryTimestamp {
                ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
                temporaryTimestamp = nil
            }
            CameraCallbackManager.shared.callPhotoFailure()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
