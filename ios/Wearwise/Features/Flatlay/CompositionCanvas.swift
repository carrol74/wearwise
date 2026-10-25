import SwiftUI
import WearwiseCore

struct CompositionCanvas: View {
    let composition: FlatlayComposition
    let images: [UUID: UIImage]
    var selectedID: UUID? = nil
    var interactive = false
    var layerLabels: [UUID: String] = [:]
    var onSelect: (UUID) -> Void = { _ in }
    var onTransform: (UUID, Double, Double, Double, Double) -> Void = { _, _, _, _, _ in }
    var onResize: (UUID, LayerResizeHandle, Double, Double) -> Void = { _, _, _, _ in }
    var onDelete: (UUID) -> Void = { _ in }
    @State private var preview: CompositionLayer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                composition.background.color
                ForEach(composition.layers) { original in
                    let layer = preview?.id == original.id ? preview! : original
                    CanvasLayerView(layer: layer, image: images[layer.assetID], canvasSize: geometry.size,
                        selected: selectedID == layer.id, label: layerLabels[layer.id] ?? "Image layer",
                        onSelect: onSelect, onResize: onResize)
                        .allowsHitTesting(false)
                        .accessibilityHidden(!interactive)
                }
                if interactive, let original = composition.layers.first(where: { $0.id == selectedID }) {
                    let layer = preview?.id == original.id ? preview! : original
                    Button { onDelete(layer.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.charcoalText).frame(width: 24, height: 24)
                            .background(Color.paperSurface, in: Circle()).wearwiseShadow()
                    }.buttonStyle(.plain).frame(width: 44, height: 44)
                        .position(CanvasHitGeometry.deleteCenter(layer, in: geometry.size))
                        .accessibilityLabel("Delete selected layer").accessibilityIdentifier("layer.delete")
                }
                if interactive {
                    CanvasInteraction(composition: composition, selectedID: selectedID,
                        onSelect: onSelect, onTransform: onTransform, onResize: onResize,
                        onDelete: onDelete, onPreview: { preview = $0 })
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(composition.width / composition.height, contentMode: .fit)
        .clipped()
        .onChange(of: selectedID) { preview = nil }
        .accessibilityHidden(!interactive)
    }
}

private struct CanvasLayerView: View {
    let layer: CompositionLayer
    let image: UIImage?
    let canvasSize: CGSize
    let selected: Bool
    let label: String
    let onSelect: (UUID) -> Void
    let onResize: (UUID, LayerResizeHandle, Double, Double) -> Void
    private var size: CGSize { CGSize(width: layer.width * canvasSize.width, height: layer.height * canvasSize.height) }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
                    .shadow(color: Color.shadowTint.opacity(0.08), radius: canvasSize.width * 0.012, y: canvasSize.width * 0.01)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            if selected {
                ZStack {
                    Rectangle().strokeBorder(Color.wearwiseBlue, lineWidth: 1.5)
                    ForEach(LayerResizeHandle.allCases, id: \.self) { handle in
                        Circle().fill(Color.paperSurface)
                            .overlay { Circle().strokeBorder(Color.wearwiseBlue, lineWidth: 1.5) }
                            .frame(width: 9, height: 9).frame(width: 44, height: 44)
                            .position(x: size.width * (handle.horizontal + 1) / 2, y: size.height * (handle.vertical + 1) / 2)
                            .accessibilityLabel("Resize \(handle.rawValue)")
                            .accessibilityIdentifier("layer.resize.\(handle.rawValue)")
                            .accessibilityAdjustableAction { direction in
                                let step = direction == .increment ? 0.02 : -0.02
                                onResize(layer.id, handle, handle.horizontal * step, handle.vertical * step)
                            }
                    }
                }
            }
        }
        .rotationEffect(.degrees(layer.rotation))
        .offset(x: (layer.x - 0.5) * canvasSize.width, y: (layer.y - 0.5) * canvasSize.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("outfit.layer.\(layer.id.uuidString)")
        .accessibilityValue("Position \(Int(layer.x * 100)), \(Int(layer.y * 100)); width \(Int(layer.width * 100)); height \(Int(layer.height * 100)); rotation \(Int(layer.rotation)) degrees")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect(layer.id) }
    }
}

enum CanvasHitGeometry {
    static func local(_ point: CGPoint, layer: CompositionLayer, size: CGSize) -> CGPoint {
        let dx = point.x - layer.x * size.width, dy = point.y - layer.y * size.height
        let angle = -layer.rotation * .pi / 180
        return CGPoint(x: dx * cos(angle) - dy * sin(angle), y: dx * sin(angle) + dy * cos(angle))
    }

    static func contains(_ point: CGPoint, layer: CompositionLayer, size: CGSize) -> Bool {
        let point = local(point, layer: layer, size: size)
        return abs(point.x) <= layer.width * size.width / 2 && abs(point.y) <= layer.height * size.height / 2
    }

    static func acceptsPinch(_ points: [CGPoint], layer: CompositionLayer, size: CGSize) -> Bool {
        points.count >= 2 && points.contains { contains($0, layer: layer, size: size) }
    }

    static func handle(at point: CGPoint, layer: CompositionLayer, size: CGSize) -> LayerResizeHandle? {
        let point = local(point, layer: layer, size: size)
        return LayerResizeHandle.allCases.first { handle in
            hypot(point.x - handle.horizontal * layer.width * size.width / 2,
                  point.y - handle.vertical * layer.height * size.height / 2) <= 22
        }
    }

    static func deleteCenter(_ layer: CompositionLayer, in size: CGSize) -> CGPoint {
        let angle = layer.rotation * .pi / 180
        let x = layer.width * size.width / 2 + 24, y = -layer.height * size.height / 2 - 24
        return CGPoint(x: min(size.width - 22, max(22, layer.x * size.width + x * cos(angle) - y * sin(angle))),
            y: min(size.height - 22, max(22, layer.y * size.height + x * sin(angle) + y * cos(angle))))
    }
}

private struct CanvasInteraction: UIViewRepresentable {
    let composition: FlatlayComposition
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onTransform: (UUID, Double, Double, Double, Double) -> Void
    let onResize: (UUID, LayerResizeHandle, Double, Double) -> Void
    let onDelete: (UUID) -> Void
    let onPreview: (CompositionLayer?) -> Void

    func makeUIView(context: Context) -> CanvasTouchView { CanvasTouchView() }
    func updateUIView(_ view: CanvasTouchView, context: Context) {
        view.composition = composition; view.selectedID = selectedID
        view.onSelect = onSelect; view.onTransform = onTransform; view.onResize = onResize
        view.onDelete = onDelete; view.onPreview = onPreview
    }
}

private final class CanvasTouchView: UIView, UIGestureRecognizerDelegate {
    var composition = FlatlayComposition()
    var selectedID: UUID?
    var onSelect: (UUID) -> Void = { _ in }
    var onTransform: (UUID, Double, Double, Double, Double) -> Void = { _, _, _, _, _ in }
    var onResize: (UUID, LayerResizeHandle, Double, Double) -> Void = { _, _, _, _ in }
    var onDelete: (UUID) -> Void = { _ in }
    var onPreview: (CompositionLayer?) -> Void = { _ in }
    private var selected: CompositionLayer? { composition.layers.first { $0.id == selectedID } }
    private var panStartedOnSelection = false
    private var panBase: CompositionLayer?
    private var resizeHandle: LayerResizeHandle?
    private var multiBase: CompositionLayer?
    private var multiOrigin = CGPoint.zero
    private var translation = CGPoint.zero
    private var scale: Double = 1
    private var angle: Double = 0
    private lazy var pan = OneFingerCanvasGesture(target: self, action: #selector(drag(_:)))
    private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(magnify(_:)))
    private lazy var rotation = UIRotationGestureRecognizer(target: self, action: #selector(rotate(_:)))
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(selectLayer(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        for recognizer in [pan, pinch, rotation, tap] {
            recognizer.delegate = self; addGestureRecognizer(recognizer)
        }
        tap.require(toFail: pan)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if event?.allTouches?.count == 1 { panStartedOnSelection = false }
        super.touchesBegan(touches, with: event)
    }

    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard bounds.width > 0, bounds.height > 0 else { return false }
        if recognizer === tap { return true }
        guard let selected else { return false }
        if recognizer === pan {
            let point = pan.origin
            if hypot(point.x - CanvasHitGeometry.deleteCenter(selected, in: bounds.size).x,
                     point.y - CanvasHitGeometry.deleteCenter(selected, in: bounds.size).y) <= 22 { return false }
            panStartedOnSelection = CanvasHitGeometry.contains(point, layer: selected, size: bounds.size)
                || CanvasHitGeometry.handle(at: point, layer: selected, size: bounds.size) != nil
            return panStartedOnSelection
        }
        if multiBase != nil { return true }
        let points = (0..<recognizer.numberOfTouches).map { recognizer.location(ofTouch: $0, in: self) }
        return panStartedOnSelection || CanvasHitGeometry.acceptsPinch(points, layer: selected, size: bounds.size)
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (recognizer === pinch && other === rotation) || (recognizer === rotation && other === pinch)
    }

    @objc private func selectLayer(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        if let selected {
            let close = CanvasHitGeometry.deleteCenter(selected, in: bounds.size)
            if hypot(point.x - close.x, point.y - close.y) <= 22 { onDelete(selected.id); return }
        }
        if let hit = composition.layers.reversed().first(where: { CanvasHitGeometry.contains(point, layer: $0, size: bounds.size) }) {
            onSelect(hit.id)
        }
    }

    @objc private func drag(_ recognizer: OneFingerCanvasGesture) {
        switch recognizer.state {
        case .began:
            panBase = selected
            if let panBase { resizeHandle = CanvasHitGeometry.handle(at: pan.origin, layer: panBase, size: bounds.size) }
        case .changed, .ended:
            guard multiBase == nil, let base = panBase else { return }
            let delta = recognizer.translation
            let x = delta.x / bounds.width, y = delta.y / bounds.height
            if recognizer.state == .ended {
                if let resizeHandle { onResize(base.id, resizeHandle, x, y) }
                else { onTransform(base.id, x, y, 1, 0) }
                onPreview(nil); panBase = nil; resizeHandle = nil
            } else if let resizeHandle {
                do { onPreview(try base.resized(handle: resizeHandle, translationX: x, translationY: y, canvasWidth: bounds.width, canvasHeight: bounds.height)) }
                catch { assertionFailure("Invalid canvas resize: \(error)") }
            } else { preview(base, x: x, y: y, scale: 1, angle: 0) }
        case .cancelled, .failed:
            panBase = nil; resizeHandle = nil
            if multiBase == nil { onPreview(nil) }
        default: break
        }
    }

    private func beginMulti(_ recognizer: UIGestureRecognizer) {
        guard multiBase == nil else { return }
        multiBase = selected
        panBase = nil; resizeHandle = nil
        multiOrigin = recognizer.location(in: self)
        translation = .zero; scale = 1; angle = 0
    }

    @objc private func magnify(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began { beginMulti(recognizer) }
        if [.began, .changed, .ended].contains(recognizer.state) {
            scale = Double(recognizer.scale)
            if recognizer.numberOfTouches == 2 {
                let point = recognizer.location(in: self)
                translation = CGPoint(x: point.x - multiOrigin.x, y: point.y - multiOrigin.y)
            }
        }
        finishMulti(recognizer)
    }

    @objc private func rotate(_ recognizer: UIRotationGestureRecognizer) {
        if recognizer.state == .began { beginMulti(recognizer) }
        if [.began, .changed, .ended].contains(recognizer.state) { angle = Double(recognizer.rotation) * 180 / .pi }
        finishMulti(recognizer)
    }

    private func finishMulti(_ recognizer: UIGestureRecognizer) {
        guard let base = multiBase else { return }
        if recognizer.state == .cancelled || recognizer.state == .failed {
            multiBase = nil; onPreview(nil); return
        }
        let x = translation.x / bounds.width, y = translation.y / bounds.height
        preview(base, x: x, y: y, scale: scale, angle: angle)
        let other = recognizer === pinch ? rotation as UIGestureRecognizer : pinch
        if recognizer.state == .ended && other.state != .began && other.state != .changed {
            onTransform(base.id, x, y, scale, angle)
            multiBase = nil; onPreview(nil)
        }
    }

    private func preview(_ layer: CompositionLayer, x: Double, y: Double, scale: Double, angle: Double) {
        var value = FlatlayComposition(layers: [layer])
        do {
            try value.transform(layer.id, translationX: x, translationY: y, magnification: scale, rotation: angle)
            onPreview(value.layers.first)
        } catch { assertionFailure("Invalid canvas transform: \(error)") }
    }
}

private final class OneFingerCanvasGesture: UIGestureRecognizer {
    private var finger: UITouch?
    private(set) var origin = CGPoint.zero
    private(set) var translation = CGPoint.zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard finger == nil, touches.count == 1, let touch = touches.first else {
            state = state == .began || state == .changed ? .cancelled : .failed
            return
        }
        finger = touch
        origin = touch.location(in: view)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let finger, touches.contains(finger) else { return }
        let point = finger.location(in: view)
        translation = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        if state == .possible {
            if hypot(translation.x, translation.y) >= 2 { state = .began }
        } else if state == .began || state == .changed { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let finger, touches.contains(finger) else { return }
        state = state == .began || state == .changed ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .began || state == .changed ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        finger = nil; origin = .zero; translation = .zero
    }
}

extension CanvasBackground {
    var color: Color {
        switch self {
        case .white: .white
        case .indigo: Color(uiColor: UIColor(rgb: 0xEDF2FE))
        case .charcoal: Color(uiColor: UIColor(rgb: 0x1C2024))
        }
    }
}

@MainActor
enum FlatlayRenderer {
    static func png(composition: FlatlayComposition, images: [UUID: UIImage]) throws -> Data {
        try composition.validate()
        guard composition.assetIDs.isSubset(of: Set(images.keys)) else { throw OutfitStoreError.missingImage }
        let renderer = ImageRenderer(content: CompositionCanvas(composition: composition, images: images)
            .frame(width: composition.width, height: composition.height))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let data = renderer.uiImage?.pngData() else { throw OutfitStoreError.renderingFailed }
        return data
    }
}
