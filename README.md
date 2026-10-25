# Wearwise

A native iOS wardrobe app for organizing clothes, composing outfits, recording what you wear, and considering purchases using cost per wear.

## Features

- **Wardrobe:** import garment photos, remove backgrounds, review suggested colors, enter item details, and search or filter your collection.
- **My character:** customize body proportions, hairstyles, facial features, and colors; insert the saved character into outfit collages.
- **Outfits:** arrange garment and character layers, resize, rotate, reorder, undo changes, and share the finished image.
- **Journal:** record worn pieces or a saved outfit, date, and notes. Wear history updates with journal edits while saved images retain their snapshots.
- **Shopping:** keep potential purchases, website quotes, and purchase estimates separate from owned clothes. Transfer acquired items into the wardrobe explicitly.
- **Brands:** keep sizing, materials, fit, price notes, and multiple inspiration photos together, with expandable owned-piece and inspiration sections.

Records and images stay in the app's local storage. No account, server, or API key is required. Light appearance uses white and navy; dark appearance uses black surfaces. Garment images retain white display backgrounds.

## Run the App

Requirements: macOS, Xcode with Swift 6 and an iOS SDK, and an iPhone or simulator. The deployment target is iOS 17. Development verification used Xcode 27.0 and the iOS 18.4 simulator runtime.

1. Open `ios/Wearwise.xcodeproj` in Xcode.
2. Select the **Wearwise** scheme and an installed iPhone simulator.
3. Run the app. For a physical iPhone, select your own development team under Signing & Capabilities and choose the connected device.
4. Add your own permitted standalone garment photos through Photos, Files, or image paste.

Background extraction requires physical-device verification. The tested iOS 18.4 simulator cannot execute one of Vision's required foreground-extraction stages. Photo selection, storage, composition, and the other interface flows can be exercised on the simulator.

To build without configuring signing:

```sh
xcodebuild -project ios/Wearwise.xcodeproj -scheme Wearwise \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

## Tests

Run the independent calculation and composition tests:

```sh
swift test --package-path packages/WearwiseCore
```

Run native tests on a disposable simulator. UI tests create saved records and exercise system photo permissions. List destinations with `xcodebuild -project ios/Wearwise.xcodeproj -scheme Wearwise -showdestinations`, then replace `SIMULATOR_UUID` below:

```sh
xcodebuild -project ios/Wearwise.xcodeproj -scheme Wearwise \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -skip-testing:WearwiseTests/ImageImportServiceTests/testRealGarmentProducesCutoutAndColors \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

The excluded foreground-extraction test belongs on a physical iPhone. Optional local-material tests skip when no external materials have been staged. Use `python3 scripts/test-garment-materials.py --materials /absolute/path/to/images` to exercise those cases with your own files. `scripts/extract-garment-materials.swift` supports separate macOS Vision review, and `scripts/generate-app-icon.swift` reproduces the application icon.

Automated checks cover calculations, composition transforms, persistence, historical image retention, and native interface flows.

## Remaining Acceptance Checks

Full physical-device accessibility, difficult-image quality, minimum-OS acceptance, and capacity/performance measurements remain open release checks.

## Project Layout

| Path | Purpose |
| --- | --- |
| `ios/Wearwise/` | SwiftUI app, local stores, image processing, character renderer, and required artwork |
| `ios/WearwiseTests/` | Native calculation, storage, rendering, and image tests with a licensed photograph |
| `ios/WearwiseUITests/` | Native interface regression flows |
| `packages/WearwiseCore/` | Foundation-only wear metrics, purchase estimates, and composition model |
| `scripts/` | Reusable icon and image verification tools |

## Hackathon Documents

- [Scope](devpost/scope.md)
- [Product requirements](devpost/prd.md)
- [Technical specification](devpost/spec.md)

Implementation and character artwork were developed with AI assistance. External material is attributed in [Third-party notices](THIRD_PARTY_NOTICES.md). The project source is available under the [MIT license](LICENSE); the bundled test photograph retains its separately stated license.
