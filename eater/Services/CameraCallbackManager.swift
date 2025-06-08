import Foundation

class CameraCallbackManager {
    static let shared = CameraCallbackManager()
    private init() {}
    
    private var onPhotoSuccess: (() -> Void)?
    private var onPhotoFailure: (() -> Void)?
    private var onPhotoStarted: (() -> Void)?
    
    func setCallbacks(
        onPhotoSuccess: (() -> Void)?,
        onPhotoFailure: (() -> Void)?,
        onPhotoStarted: (() -> Void)?
    ) {
        self.onPhotoSuccess = onPhotoSuccess
        self.onPhotoFailure = onPhotoFailure
        self.onPhotoStarted = onPhotoStarted
    }
    
    func callPhotoSuccess() {
        let callback = onPhotoSuccess
        clearCallbacks() // Clear first to prevent re-entry
        callback?()
    }
    
    func callPhotoFailure() {
        let callback = onPhotoFailure
        clearCallbacks() // Clear first to prevent re-entry
        callback?()
    }
    
    func callPhotoStarted() {
        onPhotoStarted?()
        // Don't clear callbacks here since success/failure will be called later
    }
    
    func clearCallbacks() {
        onPhotoSuccess = nil
        onPhotoFailure = nil
        onPhotoStarted = nil
    }
} 