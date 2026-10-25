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
