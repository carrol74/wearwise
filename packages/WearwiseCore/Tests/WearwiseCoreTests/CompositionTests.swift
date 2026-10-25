import Foundation
import Testing
@testable import WearwiseCore

private func compositionWithTwoLayers() -> FlatlayComposition {
    let garment = UUID()
    return FlatlayComposition(layers: [
        CompositionLayer(assetID: UUID(), garmentID: garment, x: 0.3, y: 0.4, width: 0.4, height: 0.5, rotation: -15),
        CompositionLayer(assetID: UUID(), garmentID: garment, x: 0.7, y: 0.6, width: 0.2, height: 0.3, rotation: 25)
    ])
}

@Test func combinedGestureClampsEdgesAndKeepsAspectRatio() throws {
    var canvas = compositionWithTwoLayers()
    let original = canvas.layers[0]
    try canvas.transform(original.id, translationX: -4, translationY: 5, magnification: 10, rotation: 765)
    let updated = canvas.layers[0]
    #expect(updated.x == 0 && updated.y == 1)
    #expect(updated.width == 1.5)
    #expect(updated.width / updated.height == original.width / original.height)
    #expect(updated.rotation == 30)
    try canvas.validate()
}

@Test func failedCombinedGesturePreservesEveryTransform() throws {
    for invalid in [Double.nan, .infinity, -.infinity] {
        var canvas = compositionWithTwoLayers()
        let before = canvas
        #expect(throws: CompositionError.invalidTransform) {
            try canvas.transform(canvas.layers[0].id, translationX: 0.2, translationY: 0.2, magnification: 1.2, rotation: invalid)
        }
        #expect(canvas == before)
    }
}

@Test func undoRestoresWholeGestureAndRedoRestoresItExactly() throws {
    var canvas = compositionWithTwoLayers()
    let before = canvas
    var history = CompositionHistory()
    try canvas.transform(canvas.layers[0].id, translationX: 0.2, translationY: -0.3, magnification: 1.4, rotation: 34)
    let after = canvas
    history.record(before: before, after: after)
    canvas = history.undo(canvas)
    #expect(canvas == before)
    #expect(!history.canUndo && history.canRedo)
    canvas = history.redo(canvas)
    #expect(canvas == after)
}

@Test func historyRestoresRemovedLayersAndClearsRedoAfterANewEdit() throws {
    var canvas = compositionWithTwoLayers()
    let before = canvas
    var history = CompositionHistory()
    try canvas.remove(canvas.layers[0].id)
    history.record(before: before, after: canvas)
    canvas = history.undo(canvas)
    #expect(canvas == before)
    history.record(before: canvas, after: canvas)
    #expect(history.canRedo)
    try canvas.rotate(canvas.layers[0].id, degrees: 80)
    history.record(before: before, after: canvas)
    #expect(!history.canRedo)
    #expect(history.redo(canvas) == canvas)
}

@Test func compositionRoundTripPreservesCompleteCanvas() throws {
    var original = compositionWithTwoLayers()
    original.width = 1440
    original.height = 1440
    original.background = .indigo
    #expect(try FlatlayComposition.decode(original.encoded()) == original)
}

@Test func movementChangesOnlyPosition() throws {
    var composition = compositionWithTwoLayers()
    let original = composition.layers[0]
    try composition.move(original.id, x: 0, y: 1)
    #expect(composition.layers[0].x == 0)
    #expect(composition.layers[0].y == 1)
    #expect(composition.layers[0].width == original.width)
    #expect(composition.layers[0].rotation == original.rotation)
}

@Test func resizingPreservesImageAspectRatio() throws {
    var composition = compositionWithTwoLayers()
    let original = composition.layers[0]
    try composition.resize(original.id, width: 0.8)
    #expect(composition.layers[0].height == 1)
    #expect(composition.layers[0].width / composition.layers[0].height == original.width / original.height)
}

@Test func rotationAndReorderingPreserveLayerIdentity() throws {
    var composition = compositionWithTwoLayers()
    let id = composition.layers[0].id
    let asset = composition.layers[0].assetID
    try composition.rotate(id, degrees: 405)
    try composition.reorder(id, steps: 1)
    #expect(composition.layers[1].id == id)
    #expect(composition.layers[1].assetID == asset)
    #expect(composition.layers[1].rotation == 45)
    try composition.reorder(id, steps: 1)
    #expect(composition.layers[1].id == id)
}

@Test func removingOneLayerPreservesRepeatedGarmentLayer() throws {
    var composition = compositionWithTwoLayers()
    #expect(composition.garmentIDs.count == 1)
    #expect(composition.assetIDs.count == 2)
    let second = composition.layers[1]
    try composition.remove(composition.layers[0].id)
    #expect(composition.layers == [second])
    #expect(composition.garmentIDs.count == 1)
}

@Test func snapshotIsIndependentOfLaterCompositionEdits() throws {
    var source = compositionWithTwoLayers()
    let snapshot = source
    source.background = .charcoal
    source.height = 1080
    try source.remove(source.layers[0].id)
    #expect(snapshot.layers.count == 2)
    #expect(snapshot.background == .white)
    #expect(snapshot.height == 1350)
}

@Test func canvasShapeChangesPreservePhysicalImageAspectRatio() throws {
    var composition = compositionWithTwoLayers()
    let layer = composition.layers[0]
    let aspect = layer.width * composition.width / (layer.height * composition.height)
    try composition.resizeCanvas(width: 1080, height: 1080)
    let resized = composition.layers[0]
    #expect(abs(resized.width * composition.width / (resized.height * composition.height) - aspect) < 0.000001)
    #expect(resized.x == layer.x)
    #expect(resized.y == layer.y)
}

@Test(arguments: [405.0, -405.0, 720.0, -720.0])
func rotatedLayersRemainWithinTheEditorAngleRange(_ angle: Double) throws {
    var composition = compositionWithTwoLayers()
    try composition.rotate(composition.layers[0].id, degrees: angle)
    #expect((-180...180).contains(composition.layers[0].rotation))
}

@Test(arguments: [0.0, -1.0, Double.infinity, Double.nan])
func invalidCanvasSizeIsRejected(_ size: Double) throws {
    let composition = FlatlayComposition(width: size)
    #expect(throws: CompositionError.invalidCanvas) { try composition.encoded() }
}

@Test func invalidTransformDoesNotMutateDraft() throws {
    var composition = compositionWithTwoLayers()
    let original = composition
    #expect(throws: CompositionError.invalidTransform) { try composition.resize(original.layers[0].id, width: 0) }
    #expect(throws: CompositionError.invalidTransform) { try composition.move(original.layers[0].id, x: 2, y: 0) }
    #expect(throws: CompositionError.invalidTransform) { try composition.rotate(original.layers[0].id, degrees: .nan) }
    #expect(composition == original)
}

@Test func duplicateLayerIdentifiersAreRejected() throws {
    var composition = compositionWithTwoLayers()
    composition.layers.append(composition.layers[0])
    #expect(throws: CompositionError.duplicateLayer) { try composition.encoded() }
}

@Test func missingLayerAndMalformedSavedDataAreRejected() throws {
    var composition = compositionWithTwoLayers()
    #expect(throws: CompositionError.layerNotFound) { try composition.remove(UUID()) }
    #expect(throws: (any Error).self) { try FlatlayComposition.decode(Data("incomplete JSON".utf8)) }
}

@Test func edgeResizeChangesOneDimensionAndKeepsTheOppositeEdgeFixed() throws {
    var canvas = FlatlayComposition(layers: [CompositionLayer(assetID: UUID(), width: 0.4, height: 0.3)])
    let original = canvas.layers[0]
    try canvas.resize(original.id, handle: .left, translationX: -0.1, translationY: 0)
    #expect(abs(canvas.layers[0].width - 0.5) < 0.000001)
    #expect(canvas.layers[0].height == original.height)
    #expect(abs(canvas.layers[0].x + canvas.layers[0].width / 2 - original.x - original.width / 2) < 0.000001)
    let before = canvas.layers[0]
    try canvas.resize(original.id, handle: .bottom, translationX: 0, translationY: 0.1)
    #expect(canvas.layers[0].width == before.width)
    #expect(abs(canvas.layers[0].height - 0.4) < 0.000001)
    #expect(abs(canvas.layers[0].y - canvas.layers[0].height / 2 - before.y + before.height / 2) < 0.000001)
}

@Test func rotatedEdgeResizeUsesTheLayerAxesAndLeavesOtherLayersUntouched() throws {
    var canvas = compositionWithTwoLayers()
    canvas.layers[0].rotation = 90
    let untouched = canvas.layers[1], before = canvas
    try canvas.resize(canvas.layers[0].id, handle: .right, translationX: 0, translationY: 0.1)
    #expect(canvas.layers[0].width > before.layers[0].width)
    #expect(canvas.layers[0].height == before.layers[0].height)
    #expect(canvas.layers[1] == untouched)
    var history = CompositionHistory()
    history.record(before: before, after: canvas)
    #expect(history.undo(canvas) == before)
}

@Test(arguments: [LayerResizeHandle.topLeft, .topRight, .bottomLeft, .bottomRight])
func cornerHandlesPreserveAspectAndClampToSupportedSizes(_ handle: LayerResizeHandle) throws {
    let layer = CompositionLayer(assetID: UUID(), width: 0.4, height: 0.5)
    let result = try layer.resized(handle: handle, translationX: handle.horizontal * 0.1,
        translationY: handle.vertical * 0.1, canvasWidth: 1080, canvasHeight: 1350)
    #expect(abs(result.width / result.height - layer.width / layer.height) < 0.000001)
    #expect(result.width > layer.width)
    let collapsed = try layer.resized(handle: handle, translationX: -handle.horizontal * 10,
        translationY: -handle.vertical * 10, canvasWidth: 1080, canvasHeight: 1350)
    #expect(collapsed.width >= 0.05 && collapsed.height >= 0.05)
}

@Test func independentDimensionsPersistWithoutChangingOtherLayers() throws {
    var canvas = compositionWithTwoLayers()
    let before = canvas
    try canvas.resize(canvas.layers[0].id, width: 0.8, height: 0.2)
    #expect(canvas.layers[0].width == 0.8 && canvas.layers[0].height == 0.2)
    #expect(canvas.layers[1] == before.layers[1])
    #expect(try FlatlayComposition.decode(canvas.encoded()) == canvas)
    #expect(throws: CompositionError.invalidTransform) {
        try canvas.resize(canvas.layers[0].id, width: .nan, height: 0.3)
    }
}
