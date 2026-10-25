import Photos
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class PhotoLibraryAccess: NSObject, PHPhotoLibraryChangeObserver {
    var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    var assets = PHFetchResult<PHAsset>()
    var revision = 0
    let images = PHCachingImageManager()

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
        refresh()
    }

    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }

    func requestAccess() async {
        if status == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        refresh()
    }

    func refresh() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            assets = PHAsset.fetchAssets(with: .image, options: options)
        } else {
            assets = PHFetchResult<PHAsset>()
        }
        images.stopCachingImagesForAllAssets()
        revision += 1
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
}

struct PhotoLibraryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var library = PhotoLibraryAccess()
    @State private var managingAccess = false
    @State private var loading = false
    @State private var requestID = PHInvalidImageRequestID
    @State private var selection: UUID?
    @State private var errorText: String?
    let onSelect: (Data) -> Void

    var body: some View {
        Group {
            switch library.status {
            case .authorized, .limited: photos
            case .notDetermined:
                ProgressView("Requesting photo access…")
            case .denied:
                permission(title: "Photo access is off", message: "Allow access in Settings to choose a garment photo.", action: "Open Settings", actionID: "photos.settings") { openSettings() }
            case .restricted:
                ContentUnavailableView("Photo access is restricted", systemImage: "lock", description: Text("Photo access is controlled by this device's restrictions."))
            @unknown default:
                ContentUnavailableView("Photos are unavailable", systemImage: "photo")
            }
        }
        .background(Color.wardrobeBackground)
        .navigationTitle("Photos").navigationBarTitleDisplayMode(.inline)
        .task { await library.requestAccess() }
        .overlay {
            if loading {
                ZStack {
                    Color.shadowTint.opacity(0.18).ignoresSafeArea()
                    ProgressView("Loading photo…").padding(24)
                        .background(Color.paperSurface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { library.refresh() }
        }
        .onDisappear { cancelLoading() }
        .wearwiseErrorToast("Could not load photo", message: $errorText)
    }

    private func permission(title: String, message: String, action: String, actionID: String = "photos.request", perform: @escaping () -> Void) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle").font(.largeTitle).accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(Color.supportingText).multilineTextAlignment(.center)
            Button(action, action: perform).buttonStyle(WearwiseButtonStyle())
                .accessibilityIdentifier(actionID)
        }.padding(24).frame(maxWidth: 360).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photos: some View {
        // Keep each cell's index attached to its original fetch result during access changes.
        let snapshot = library.assets
        return VStack(spacing: 0) {
            if library.status == .limited {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected photos only").font(.subheadline.weight(.semibold))
                    HStack {
                        Button(action: managePhotos) {
                            Text("Manage photos").frame(minHeight: 44).contentShape(Rectangle())
                        }.disabled(managingAccess).accessibilityIdentifier("photos.manage")
                        Spacer()
                        Button(action: openSettings) {
                            Text("Settings").frame(minHeight: 44).contentShape(Rectangle())
                        }.accessibilityIdentifier("photos.settings")
                    }.buttonStyle(.borderless)
                }.padding().background(Color.paperSurface)
            }
            if snapshot.count == 0 {
                ContentUnavailableView(library.status == .limited ? "No photos selected" : "No photos yet", systemImage: "photo", description: Text(library.status == .limited ? "Use Manage photos to allow access to the images you want." : "Photos added to your library will appear here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: textSize.isAccessibilitySize ? 2 : 3), spacing: 3) {
                        ForEach(0..<snapshot.count, id: \.self) { index in
                            let asset = snapshot.object(at: index)
                            Button { choose(asset) } label: {
                                PhotoLibraryThumbnail(asset: asset, images: library.images)
                            }.buttonStyle(.plain)
                                .accessibilityLabel("Photo \(index + 1)")
                                .accessibilityIdentifier("photos.asset.\(index)")
                        }
                    }.id(library.revision).padding(3)
                }
            }
        }
    }

    private func managePhotos() {
        guard !managingAccess else { return }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            errorText = "Photo access settings could not be opened. Please try again."
            return
        }
        while let presented = controller.presentedViewController { controller = presented }
        managingAccess = true
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { _ in
            Task { @MainActor in
                managingAccess = false
                library.refresh()
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func cancelLoading() {
        selection = nil
        if requestID != PHInvalidImageRequestID { library.images.cancelImageRequest(requestID) }
        requestID = PHInvalidImageRequestID
        loading = false
    }

    private func choose(_ asset: PHAsset) {
        cancelLoading()
        let token = UUID()
        selection = token
        loading = true
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        requestID = library.images.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
            let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let failure = (info?[PHImageErrorKey] as? Error)?.localizedDescription
            Task { @MainActor in
                guard selection == token else { return }
                requestID = PHInvalidImageRequestID
                loading = false
                if cancelled { return }
                if let data { onSelect(data) }
                else { errorText = failure ?? "This photo could not be downloaded. Please try again." }
            }
        }
    }
}

private struct PhotoLibraryThumbnail: View {
    let asset: PHAsset
    let images: PHCachingImageManager
    @State private var image: UIImage?
    @State private var requestID = PHInvalidImageRequestID
    @State private var token: UUID?

    var body: some View {
        Color.cutoutSurface.aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image { GeometryReader { geometry in
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } }
                else { Image(systemName: "photo").foregroundStyle(Color.primaryFill) }
            }
            .clipped()
            .contentShape(Rectangle())
            .onAppear {
                let current = UUID(); token = current
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.resizeMode = .fast
                requestID = images.requestImage(for: asset, targetSize: CGSize(width: 320, height: 320), contentMode: .aspectFill, options: options) { result, _ in
                    Task { @MainActor in if token == current { image = result } }
                }
            }
            .onDisappear {
                token = nil
                if requestID != PHInvalidImageRequestID { images.cancelImageRequest(requestID) }
            }
    }
}
