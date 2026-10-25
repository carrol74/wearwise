import SwiftUI

struct GarmentImagePanel: View {
    let garment: Garment
    var allowsReplacement = true
    @State private var replacingImage = false

    var body: some View {
        GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset)
            .containerRelativeFrame(.vertical) { height, _ in min(260, max(140, height * 0.34)) }
            .frame(maxWidth: .infinity)
            .background(Color.cutoutSurface, in: RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if allowsReplacement {
                    Button { replacingImage = true } label: {
                        Label("Replace", systemImage: "photo").labelStyle(.iconOnly)
                            .font(.caption.weight(.medium)).padding(10)
                            .background(Color.paperSurface, in: Capsule())
                    }.accessibilityLabel("Replace image").padding(12)
                }
            }
            .sheet(isPresented: $replacingImage) {
                ImportView(collection: garment.collection, replacing: garment, startInLibrary: true)
            }
    }
}
