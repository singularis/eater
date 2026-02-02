import SwiftUI
import PhotosUI

struct MultiplePhotoPicker: UIViewControllerRepresentable {
  @Binding var selectedImages: [UIImage]
  @Environment(\.presentationMode) var presentationMode
  
  func makeUIViewController(context: Context) -> PHPickerViewController {
    var config = PHPickerConfiguration()
    config.selectionLimit = 10 // Allow up to 10 photos
    config.filter = .images
    
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = context.coordinator
    return picker
  }
  
  func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let parent: MultiplePhotoPicker
    
    init(_ parent: MultiplePhotoPicker) {
      self.parent = parent
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      parent.presentationMode.wrappedValue.dismiss()
      
      guard !results.isEmpty else { return }
      
      var loadedImages: [UIImage] = []
      let group = DispatchGroup()
      
      for result in results {
        group.enter()
        result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
          defer { group.leave() }
          
          if let image = object as? UIImage {
            loadedImages.append(image)
          }
        }
      }
      
      group.notify(queue: .main) {
        self.parent.selectedImages = loadedImages
      }
    }
  }
}

// Extension to CameraButtonView for multiple photos
struct MultiplePhotoUploadButton: View {
  @State private var showPicker = false
  @State private var selectedImages: [UIImage] = []
  @State private var isUploading = false
  
  var onPhotosSelected: (([UIImage]) -> Void)?
  
  var body: some View {
    Button(action: {
      HapticsService.shared.select()
      showPicker = true
    }) {
      HStack(spacing: 4) {
        Image(systemName: "photo.on.rectangle.angled")
          .font(.system(size: 18))
        Text(loc("camera.upload_multiple", "Upload Multiple"))
          .font(.system(size: 16, weight: .medium, design: .rounded))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
      }
      .padding(.vertical, 24)
      .frame(maxWidth: .infinity)
      .background(
        LinearGradient(
          gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.6)]),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .cornerRadius(AppTheme.cornerRadius)
      .foregroundColor(.white)
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
          .stroke(Color.blue.opacity(0.5), lineWidth: 2)
      )
      .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    .disabled(isUploading)
    .sheet(isPresented: $showPicker) {
      MultiplePhotoPicker(selectedImages: $selectedImages)
    }
    .onChange(of: selectedImages) { newImages in
      guard !newImages.isEmpty else { return }
      isUploading = true
      
      // Process selected images
      onPhotosSelected?(newImages)
      
      // Reset after processing
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        selectedImages = []
        isUploading = false
      }
    }
  }
}
