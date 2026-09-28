import PhotosUI
import SwiftUI
import VisionKit

struct ImportMenu: View {
    let importService: ImportService
    let onAddManually: () -> Void
    let onImportFinished: () -> Void

    @State private var isScanning = false
    @State private var isPickingPhotos = false
    @State private var photoSelection: [PhotosPickerItem] = []

    var body: some View {
        Menu("Add", systemImage: "plus") {
            Button("Scan Receipt", systemImage: "doc.viewfinder") {
                isScanning = true
            }
            .disabled(!VNDocumentCameraViewController.isSupported)

            Button("Import Screenshots", systemImage: "photo.on.rectangle") {
                isPickingPhotos = true
            }

            Button("Add Manually", systemImage: "square.and.pencil") {
                onAddManually()
            }
        }
        .disabled(importService.progress != nil)
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScannerView { result in
                isScanning = false
                switch result {
                case .success(let pages) where !pages.isEmpty:
                    Task {
                        if await importService.importScannedPages(pages) {
                            onImportFinished()
                        }
                    }
                case .success:
                    break
                case .failure(let error):
                    importService.errorMessage = error.localizedDescription
                }
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $isPickingPhotos,
            selection: $photoSelection,
            selectionBehavior: .ordered,
            matching: .screenshots
        )
        .onChange(of: photoSelection) {
            guard !photoSelection.isEmpty else { return }
            let items = photoSelection
            photoSelection = []
            Task {
                if await importService.importScreenshots(items) {
                    onImportFinished()
                }
            }
        }
    }
}
