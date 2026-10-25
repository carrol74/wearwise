import Foundation

public enum CanvasBackground: String, Codable, CaseIterable, Sendable {
    case white, indigo, charcoal
}

public struct CompositionLayer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var assetID: UUID
    public var garmentID: UUID?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rotation: Double

    public init(id: UUID = UUID(), assetID: UUID, garmentID: UUID? = nil,
                x: Double = 0.5, y: Double = 0.5, width: Double, height: Double, rotation: Double = 0) {
        self.id = id
        self.assetID = assetID
        self.garmentID = garmentID
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
    }
}

public struct FlatlayComposition: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var background: CanvasBackground
    public var layers: [CompositionLayer]

    public init(width: Double = 1080, height: Double = 1350,
                background: CanvasBackground = .white, layers: [CompositionLayer] = []) {
        self.width = width
        self.height = height
        self.background = background
        self.layers = layers
    }

    public var assetIDs: Set<UUID> { Set(layers.map(\.assetID)) }
    public var garmentIDs: Set<UUID> { Set(layers.compactMap(\.garmentID)) }

    public func validate() throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw CompositionError.invalidCanvas
        }
        guard Set(layers.map(\.id)).count == layers.count else { throw CompositionError.duplicateLayer }
        for layer in layers {
            guard layer.x.isFinite, layer.y.isFinite, (0...1).contains(layer.x), (0...1).contains(layer.y),
                  layer.width.isFinite, layer.height.isFinite, layer.width > 0, layer.height > 0,
                  layer.rotation.isFinite else { throw CompositionError.invalidTransform }
        }
    }

    public func encoded() throws -> Data {
        try validate()
        return try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> Self {
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }

    public mutating func move(_ id: UUID, x: Double, y: Double) throws {
        let index = try index(of: id)
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else {
            throw CompositionError.invalidTransform
        }
        layers[index].x = x
        layers[index].y = y
    }

    public mutating func transform(_ id: UUID, translationX: Double, translationY: Double,
                                   magnification: Double, rotation: Double) throws {
        let layer = layers[try index(of: id)]
        guard translationX.isFinite, translationY.isFinite, magnification.isFinite,
              magnification > 0, rotation.isFinite else { throw CompositionError.invalidTransform }
        var updated = self
        try updated.move(id, x: min(1, max(0, layer.x + translationX)),
                         y: min(1, max(0, layer.y + translationY)))
        try updated.resize(id, width: min(1.5, max(0.05, layer.width * magnification)))
        try updated.rotate(id, degrees: layer.rotation + rotation)
        try updated.validate()
        self = updated
    }

    public mutating func resize(_ id: UUID, width: Double) throws {
        let index = try index(of: id)
        guard width.isFinite, width > 0 else { throw CompositionError.invalidTransform }
        let newHeight = layers[index].height * width / layers[index].width
        guard newHeight.isFinite, newHeight > 0 else { throw CompositionError.invalidTransform }
        layers[index].height = newHeight
        layers[index].width = width
    }

    public mutating func rotate(_ id: UUID, degrees: Double) throws {
        let index = try index(of: id)
        guard degrees.isFinite else { throw CompositionError.invalidTransform }
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        layers[index].rotation = remainder > 180 ? remainder - 360 : (remainder < -180 ? remainder + 360 : remainder)
    }

    public mutating func resizeCanvas(width: Double, height: Double) throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw CompositionError.invalidCanvas }
        var updated = self
        for index in updated.layers.indices {
            updated.layers[index].height *= width * self.height / (self.width * height)
        }
        updated.width = width
        updated.height = height
        try updated.validate()
        self = updated
    }

    public mutating func reorder(_ id: UUID, steps: Int) throws {
        let index = try index(of: id)
        let target = min(layers.count - 1, max(0, index + steps))
        let layer = layers.remove(at: index)
        layers.insert(layer, at: target)
    }

    public mutating func remove(_ id: UUID) throws {
        layers.remove(at: try index(of: id))
    }

    private func index(of id: UUID) throws -> Int {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { throw CompositionError.layerNotFound }
        return index
    }
}

public enum CompositionError: LocalizedError, Equatable {
    case invalidCanvas, invalidTransform, duplicateLayer, layerNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidCanvas: "The canvas size is invalid. Reopen the saved outfit."
        case .invalidTransform: "The layer could not be positioned. Release the gesture and try again."
        case .duplicateLayer: "This outfit contains duplicate layer identifiers. Reopen the saved outfit."
        case .layerNotFound: "This layer is no longer in the outfit. Select another layer."
        }
    }
}

public struct CompositionHistory: Sendable {
    private var past: [FlatlayComposition] = []
    private var future: [FlatlayComposition] = []
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public init() {}

    public mutating func record(before: FlatlayComposition, after: FlatlayComposition) {
        guard before != after else { return }
        past.append(before)
        future.removeAll()
    }

    public mutating func undo(_ current: FlatlayComposition) -> FlatlayComposition {
        guard let previous = past.popLast() else { return current }
        future.append(current)
        return previous
    }

    public mutating func redo(_ current: FlatlayComposition) -> FlatlayComposition {
        guard let next = future.popLast() else { return current }
        past.append(current)
        return next
    }
}

public enum LayerResizeHandle: String, CaseIterable, Sendable {
    case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight

    public var horizontal: Double {
        switch self {
        case .left, .topLeft, .bottomLeft: -1
        case .right, .topRight, .bottomRight: 1
        default: 0
        }
    }

    public var vertical: Double {
        switch self {
        case .top, .topLeft, .topRight: -1
        case .bottom, .bottomLeft, .bottomRight: 1
        default: 0
        }
    }
}

extension CompositionLayer {
    public func resized(handle: LayerResizeHandle, translationX: Double, translationY: Double,
                        canvasWidth: Double, canvasHeight: Double) throws -> Self {
        guard translationX.isFinite, translationY.isFinite, canvasWidth.isFinite, canvasHeight.isFinite,
              canvasWidth > 0, canvasHeight > 0, width > 0, height > 0 else { throw CompositionError.invalidTransform }
        let angle = rotation * .pi / 180
        let dx = translationX * canvasWidth, dy = translationY * canvasHeight
        let localX = dx * cos(angle) + dy * sin(angle)
        let localY = -dx * sin(angle) + dy * cos(angle)
        var newWidth = width, newHeight = height
        if handle.horizontal != 0 && handle.vertical != 0 {
            let xScale = handle.horizontal * localX / (width * canvasWidth)
            let yScale = handle.vertical * localY / (height * canvasHeight)
            let proposed = 1 + (abs(xScale) > abs(yScale) ? xScale : yScale)
            let factor = min(min(1.5 / width, 1.5 / height), max(max(0.05 / width, 0.05 / height), proposed))
            newWidth *= factor
            newHeight *= factor
        } else {
            if handle.horizontal != 0 { newWidth = min(1.5, max(0.05, width + handle.horizontal * localX / canvasWidth)) }
            if handle.vertical != 0 { newHeight = min(1.5, max(0.05, height + handle.vertical * localY / canvasHeight)) }
        }
        let centerX = (newWidth - width) * canvasWidth * handle.horizontal / 2
        let centerY = (newHeight - height) * canvasHeight * handle.vertical / 2
        var result = self
        result.width = newWidth
        result.height = newHeight
        result.x = min(1, max(0, x + (centerX * cos(angle) - centerY * sin(angle)) / canvasWidth))
        result.y = min(1, max(0, y + (centerX * sin(angle) + centerY * cos(angle)) / canvasHeight))
        return result
    }
}

extension FlatlayComposition {
    public mutating func resize(_ id: UUID, width: Double, height: Double) throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw CompositionError.invalidTransform }
        let index = try index(of: id)
        layers[index].width = width
        layers[index].height = height
    }

    public mutating func resize(_ id: UUID, handle: LayerResizeHandle, translationX: Double, translationY: Double) throws {
        let index = try index(of: id)
        layers[index] = try layers[index].resized(handle: handle, translationX: translationX, translationY: translationY,
                                                 canvasWidth: width, canvasHeight: height)
    }
}
