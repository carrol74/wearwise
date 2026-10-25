import Foundation
import SwiftData
import WearwiseCore

@Model
final class Outfit {
  @Attribute(.unique) var id: UUID
  var name: String
  var compositionData: Data
  var createdAt: Date
  var updatedAt: Date
  @Relationship(deleteRule: .nullify, inverse: \Garment.outfits) var garments: [Garment]
  @Relationship(deleteRule: .nullify, inverse: \AssetRecord.outfits) var assets: [AssetRecord]

  init(id: UUID = UUID(), name: String, compositionData: Data, createdAt: Date = Date()) {
    self.id = id
    self.name = name
    self.compositionData = compositionData
    self.createdAt = createdAt
    self.updatedAt = createdAt
    self.garments = []
    self.assets = []
  }

  func composition() throws -> FlatlayComposition {
    try FlatlayComposition.decode(compositionData)
  }
}

@Model
final class JournalEntry {
  @Attribute(.unique) var id: UUID
  var name: String
  var date: Date
  var note: String
  var compositionData: Data
  var updatedAt: Date
  var wearingRecorded: Bool = false
  var sourceOutfitID: UUID? = nil
  @Relationship(deleteRule: .nullify, inverse: \AssetRecord.renderedEntries) var renderedAsset: AssetRecord?
  @Relationship(deleteRule: .nullify, inverse: \Garment.journalEntries) var garments: [Garment] = []
  @Relationship(deleteRule: .nullify, inverse: \AssetRecord.journalEntries) var assets:
    [AssetRecord] = []
  @Relationship(deleteRule: .nullify, inverse: \WearRecord.journalEntries) var wearRecords:
    [WearRecord] = []

  init(name: String, date: Date, note: String, compositionData: Data) {
    id = UUID()
    self.name = name
    self.date = date
    self.note = note
    self.compositionData = compositionData
    updatedAt = Date()
  }

  func composition() throws -> FlatlayComposition { try FlatlayComposition.decode(compositionData) }
}

@Model
final class WearRecord {
  @Attribute(.unique) var id: UUID
  var date: Date
  var garment: Garment?
  var journalEntries: [JournalEntry] = []
  var retainedAfterEntryDeletion: Bool = false

  init(date: Date, garment: Garment) {
    id = UUID()
    self.date = date
    self.garment = garment
  }
}
