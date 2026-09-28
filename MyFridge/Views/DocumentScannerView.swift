import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: (Result<[UIImage], any Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    /** The coordinator is made once, so give it the latest callback on every update. */
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {
        context.coordinator.onComplete = onComplete
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onComplete: (Result<[UIImage], any Error>) -> Void

        init(onComplete: @escaping (Result<[UIImage], any Error>) -> Void) {
            self.onComplete = onComplete
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onComplete(.success((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onComplete(.success([]))
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            onComplete(.failure(error))
        }
    }
}
