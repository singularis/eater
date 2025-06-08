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
        
        print("CameraCallbackManager: Callbacks set - onPhotoSuccess = \(onPhotoSuccess != nil ? "not nil" : "nil")")
    }
    
    func callPhotoSuccess() {
        print("CameraCallbackManager: Calling onPhotoSuccess - \(onPhotoSuccess != nil ? "not nil" : "nil")")
        let callback = onPhotoSuccess
        clearCallbacks() // Clear first to prevent re-entry
        callback?()
        print("CameraCallbackManager: onPhotoSuccess called and callbacks cleared")
    }
    
    func callPhotoFailure() {
        print("CameraCallbackManager: Calling onPhotoFailure")
        let callback = onPhotoFailure
        clearCallbacks() // Clear first to prevent re-entry
        callback?()
        print("CameraCallbackManager: onPhotoFailure called and callbacks cleared")
    }
    
    func callPhotoStarted() {
        print("CameraCallbackManager: Calling onPhotoStarted")
        onPhotoStarted?()
        // Don't clear callbacks here since success/failure will be called later
    }
    
    func clearCallbacks() {
        print("CameraCallbackManager: Clearing callbacks")
        onPhotoSuccess = nil
        onPhotoFailure = nil
        onPhotoStarted = nil
    }
} 