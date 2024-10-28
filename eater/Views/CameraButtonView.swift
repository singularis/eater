import SwiftUI
import AVFoundation

struct CameraButtonView: View {
    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false

    var body: some View {
        Button(action: {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCamera = true
            } else {
                cameraUnavailableAlert = true
            }
        }) {
            Text("Take food photo")
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
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

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                GRPCService().sendPhoto(image: image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

