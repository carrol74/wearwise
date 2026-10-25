import Foundation
import SwiftData
import WearwiseCore
import UIKit

@MainActor
struct JournalStore {
  let context: ModelContext
  var assets: AssetStore = .shared
  var calendar = Calendar.current

  @discardableResult
  func saveRecord(name: String, date: Date, note: String, composition: FlatlayComposition,
    updating entry: JournalEntry? = nil, from outfit: Outfit? = nil, now: Date = Date()) throws -> JournalEntry {
    guard calendar.startOfDay(for: date) <= calendar.startOfDay(for: now) else { throw JournalError.futureWearing }
    return try persist(name: name, date: date, note: note, composition: composition,
      updating: entry, from: outfit, recordingWearing: true)
  }

  @discardableResult
  func save(name: String, date: Date, note: String, composition: FlatlayComposition,
    updating entry: JournalEntry? = nil, from outfit: Outfit? = nil) throws -> JournalEntry {
    try persist(name: name, date: date, note: note, composition: composition,
      updating: entry, from: outfit, recordingWearing: false)
  }

  @discardableResult
  private func persist(
    name: String, date: Date, note: String, composition: FlatlayComposition,
    updating entry: JournalEntry? = nil, from outfit: Outfit? = nil, recordingWearing: Bool
  ) throws -> JournalEntry {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty else { throw OutfitStoreError.invalidName }
    guard !composition.layers.isEmpty else { throw OutfitStoreError.emptyComposition }
    let encoded = try composition.encoded()
    let assets = try context.fetch(FetchDescriptor<AssetRecord>()).filter {
      composition.assetIDs.contains($0.id)
    }
    let garments = try context.fetch(FetchDescriptor<Garment>()).filter {
      composition.garmentIDs.contains($0.id)
    }
    guard Set(assets.map(\.id)) == composition.assetIDs else { throw OutfitStoreError.missingImage }
    guard Set(garments.map(\.id)) == composition.garmentIDs else {
      throw OutfitStoreError.missingGarment
    }
    let preserved = Set(try entry?.composition().layers.map(\.id) ?? []).union(
      try outfit?.composition().layers.map(\.id) ?? [])
    for garment in garments
    where garment.status != GarmentStatus.owned && garment.status != GarmentStatus.candidate {
      guard
        composition.layers.filter({ $0.garmentID == garment.id }).allSatisfy({
          preserved.contains($0.id)
        })
      else { throw OutfitStoreError.retiredGarment }
    }
    if recordingWearing {
      guard !garments.isEmpty else { throw JournalError.noGarments }
      let retained = Set(entry?.garments.map(\.id) ?? [])
      guard garments.allSatisfy({ $0.status == GarmentStatus.owned || retained.contains($0.id) }) else {
        throw JournalError.unavailableGarment
      }
    }
    if !recordingWearing, let entry, entry.wearingRecorded {
      guard composition.garmentIDs == Set(entry.garments.map(\.id)) else {
        throw JournalError.recordedGarmentsChanged
      }
    }
    let images = try OutfitStore(context: context, assets: self.assets).images(for: composition)
    let rendered: AssetRecord
    let createdImage: Bool
    if let entry, try entry.composition() == composition, let previous = entry.renderedAsset {
      guard UIImage(data: try self.assets.loadData(for: previous)) != nil else { throw OutfitStoreError.missingImage }
      rendered = previous
      createdImage = false
    } else {
      let png = try FlatlayRenderer.png(composition: composition, images: images)
      rendered = try self.assets.savePNG(png, id: UUID())
      rendered.kind = "diary"
      createdImage = true
    }
    let result =
      entry ?? JournalEntry(name: cleanName, date: date, note: note, compositionData: encoded)
    let previous = entry.map { (name: $0.name, date: $0.date, note: $0.note, composition: $0.compositionData,
      assets: $0.assets, garments: $0.garments, updatedAt: $0.updatedAt, renderedAsset: $0.renderedAsset, sourceOutfitID: $0.sourceOutfitID, wears: $0.wearRecords, recorded: $0.wearingRecorded) }
    let renderedURL = self.assets.url(for: rendered)
    do {
      result.name = cleanName
      result.date = date
      result.note = note
      result.compositionData = encoded
      result.assets = assets
      result.garments = garments
      result.updatedAt = Date()
      if let outfit { result.sourceOutfitID = outfit.id }
      if createdImage { context.insert(rendered) }
      result.renderedAsset = rendered
      if entry == nil { context.insert(result) }
      if recordingWearing { try synchronizeWearing(result) }
      try context.save()
      return result
    } catch {
      if let entry, let previous {
        entry.name = previous.name
        entry.date = previous.date
        entry.note = previous.note
        entry.compositionData = previous.composition
        entry.assets = previous.assets
        entry.garments = previous.garments
        entry.updatedAt = previous.updatedAt
        entry.renderedAsset = previous.renderedAsset
        entry.sourceOutfitID = previous.sourceOutfitID
        entry.wearRecords = previous.wears
        entry.wearingRecorded = previous.recorded
      }
      context.rollback()
      if createdImage { try FileManager.default.removeItem(at: renderedURL) }
      throw error
    }
  }

  private func synchronizeWearing(_ entry: JournalEntry) throws {
    let day = calendar.startOfDay(for: entry.date)
    var records = try context.fetch(FetchDescriptor<WearRecord>())
    let previous = entry.wearRecords
    var desired: [WearRecord] = []
    for garment in entry.garments {
      if let record = records.first(where: { $0.garment?.id == garment.id && calendar.isDate($0.date, inSameDayAs: day) }) {
        desired.append(record)
      } else {
        let record = WearRecord(date: day, garment: garment)
        context.insert(record)
        records.append(record)
        desired.append(record)
      }
    }
    entry.wearRecords = desired
    for record in previous where !desired.contains(where: { $0.id == record.id })
      && record.journalEntries.isEmpty && !record.retainedAfterEntryDeletion {
      context.delete(record)
    }
    entry.wearingRecorded = true
  }

  func recordExistingEntries(now: Date = Date()) throws {
    for entry in try context.fetch(FetchDescriptor<JournalEntry>())
      where !entry.wearingRecorded && !entry.garments.isEmpty
        && calendar.startOfDay(for: entry.date) <= calendar.startOfDay(for: now) {
      try recordWearing(entry, now: now)
    }
  }

  func deleteRecord(_ entry: JournalEntry) throws {
    // Reject immutable stores before changing the live graph. SwiftData rollback
    // does not reliably re-register a deleted model in an existing query.
    guard context.container.configurations.allSatisfy({ $0.allowsSave }) else {
      throw CocoaError(.fileWriteNoPermission)
    }
    let previous = (assets: entry.assets, garments: entry.garments, rendered: entry.renderedAsset, wears: entry.wearRecords)
    let wearLinks = entry.wearRecords.map { (record: $0, garment: $0.garment, entries: $0.journalEntries) }
    let garmentLinks = entry.garments.map { (garment: $0, records: $0.wearRecords) }
    do {
      entry.wearRecords = []
      for record in previous.wears where record.journalEntries.isEmpty && !record.retainedAfterEntryDeletion {
        context.delete(record)
      }
      context.delete(entry)
      try context.save()
    } catch {
      context.rollback()
      // Keep the original entry available for retry if a write fails after the
      // configuration check (for example, the device runs out of storage).
      context.insert(entry)
      entry.assets = previous.assets
      entry.garments = previous.garments
      entry.renderedAsset = previous.rendered
      for saved in wearLinks {
        context.insert(saved.record)
        saved.record.garment = saved.garment
        saved.record.journalEntries = saved.entries
      }
      entry.wearRecords = previous.wears
      for saved in garmentLinks { saved.garment.wearRecords = saved.records }
      throw error
    }
  }

  func recordComposition(_ garments: [Garment], preserving original: FlatlayComposition? = nil) throws -> FlatlayComposition {
    guard !garments.isEmpty else { throw JournalError.noGarments }
    var composition = FlatlayComposition()
    let columns = min(3, garments.count)
    let rows = (garments.count + columns - 1) / columns
    for (index, garment) in garments.enumerated() {
      var layer: CompositionLayer
      if let retained = original?.layers.first(where: { $0.garmentID == garment.id }) { layer = retained }
      else { layer = try OutfitStore(context: context, assets: assets).layer(for: garment, in: composition) }
      let factor = min(0.84 / Double(columns) / layer.width, 0.84 / Double(rows) / layer.height)
      layer.width *= factor
      layer.height *= factor
      layer.x = (Double(index % columns) + 0.5) / Double(columns)
      layer.y = (Double(index / columns) + 0.5) / Double(rows)
      layer.rotation = 0
      composition.layers.append(layer)
    }
    try composition.validate()
    return composition
  }

  @discardableResult
  func useToday(_ outfit: Outfit) throws -> JournalEntry {
    try save(
      name: outfit.name, date: Date(), note: "", composition: outfit.composition(), from: outfit)
  }

  @discardableResult
  func saveAsOutfit(_ entry: JournalEntry) throws -> Outfit {
    try OutfitStore(context: context, assets: assets).save(
      name: entry.name, composition: entry.composition(), from: entry)
  }

  func recordWearing(_ entry: JournalEntry, now: Date = Date()) throws {
    let day = calendar.startOfDay(for: entry.date)
    guard day <= calendar.startOfDay(for: now) else { throw JournalError.futureWearing }
    guard !entry.garments.isEmpty else { throw JournalError.noGarments }
    if entry.wearingRecorded { return }
    var records = try context.fetch(FetchDescriptor<WearRecord>())
    let previous = (records: entry.wearRecords, recorded: entry.wearingRecorded, updatedAt: entry.updatedAt)
    let garmentRecords = entry.garments.map { (garment: $0, records: $0.wearRecords) }
    var created: [WearRecord] = []
    do {
      for garment in entry.garments {
        let record: WearRecord
        if let existing = records.first(where: {
          $0.garment?.id == garment.id && calendar.isDate($0.date, inSameDayAs: day)
        }) {
          record = existing
        } else {
          record = WearRecord(date: day, garment: garment)
          context.insert(record)
          records.append(record)
          created.append(record)
        }
        entry.wearRecords.append(record)
      }
      entry.wearingRecorded = true
      entry.updatedAt = Date()
      try context.save()
    } catch {
      entry.wearRecords = previous.records
      entry.wearingRecorded = previous.recorded
      entry.updatedAt = previous.updatedAt
      for record in created { record.garment = nil }
      for saved in garmentRecords { saved.garment.wearRecords = saved.records }
      context.rollback()
      throw error
    }
  }

  func delete(_ entry: JournalEntry) throws {
    let previous = (assets: entry.assets, garments: entry.garments, rendered: entry.renderedAsset, wears: entry.wearRecords)
    let retained = entry.wearRecords.map { (record: $0, retained: $0.retainedAfterEntryDeletion) }
    do {
      for record in entry.wearRecords { record.retainedAfterEntryDeletion = true }
      context.delete(entry)
      context.processPendingChanges()
      try context.save()
    } catch {
      context.rollback()
      entry.assets = previous.assets
      entry.garments = previous.garments
      entry.renderedAsset = previous.rendered
      entry.wearRecords = previous.wears
      for saved in retained { saved.record.retainedAfterEntryDeletion = saved.retained }
      throw error
    }
  }

  func reverseWearing(_ entry: JournalEntry) throws {
    let previous = (records: entry.wearRecords, recorded: entry.wearingRecorded, updatedAt: entry.updatedAt)
    let garmentRecords = previous.records.compactMap { record in record.garment.map { (garment: $0, records: $0.wearRecords) } }
    do {
      let records = entry.wearRecords
      entry.wearRecords = []
      for record in records
      where record.journalEntries.isEmpty && !record.retainedAfterEntryDeletion {
        context.delete(record)
      }
      entry.wearingRecorded = false
      entry.updatedAt = Date()
      try context.save()
    } catch {
      entry.wearRecords = previous.records
      entry.wearingRecorded = previous.recorded
      entry.updatedAt = previous.updatedAt
      for saved in garmentRecords { saved.garment.wearRecords = saved.records }
      context.rollback()
      throw error
    }
  }
}

enum JournalError: LocalizedError {
  case futureWearing, noGarments, recordedGarmentsChanged, unavailableGarment
  var errorDescription: String? {
    switch self {
    case .futureWearing: "Choose today or an earlier date for your journal entry."
    case .unavailableGarment: "Choose pieces you own. Shopping items can be styled in Outfits."
    case .noGarments: "Add garments before recording wearing."
    case .recordedGarmentsChanged: "Undo this entry's wearing before changing its garments."
    }
  }
}
