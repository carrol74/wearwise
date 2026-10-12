---
doc: prd
status: draft
---

# Wearwise — Product Requirements

A personal wardrobe and scrapbook-style outfit journal that supports styling, purchasing, and decluttering decisions.

Sources: scope.md > The Unique Kernel, The Core Loop, The POC Boundary.

## Planning Basis

The learner requested that established requirements be developed first and unresolved decisions be collected for one later review. This draft formalizes those requirements and labels proposed behaviors separately. Scope and product approval remain pending. Decision identifiers refer to Open Questions below; the ignored local review notes provide a reader-friendly companion.

## The Core Journey

1. Add owned garments using saved product images, web images, or personal images.
2. Process the images into cutouts and editable tags; save garment attributes.
3. Browse the wardrobe to understand what is owned and available for an outfit.
4. Add a potential purchase and compose it with owned garments on a flatlay canvas.
5. Save an outfit as an OOTD journal entry, including a personalized character sticker.
6. Record or estimate garment use and inspect duration, wear count, condition, and cost per wear.
7. Use these facts to decide what to buy, retain, or retire.
8. Save brands to revisit as part of ongoing taste and styling exploration.

These paths share garment records. Styling, journaling, and use records must remain connected when the user returns.

## Screens and Layout

The learner established the functional areas, but has not selected a navigation layout. The following organization is proposed for review under D01 and D06:

| Surface | Purpose | Main connections |
| --- | --- | --- |
| Wardrobe | Browse, filter, add, and edit owned and potential items | Garment details; flatlay composer |
| Garment details | Maintain attributes, wear records, reference values, and condition | Wardrobe; outfits containing the garment |
| Flatlay composer | Arrange cutouts from owned and potential items | Saved outfits; journal; image export |
| Outfit journal | View dated OOTD entries and personalized stickers | Saved composition; associated garments |
| Brands | Record brands, links, and inspiration notes | Brand-linked garments |

Surface names describe responsibilities; separate full pages are not a requirement. The accepted device target will determine navigation and responsive layout.

## Look and Feel

Established direction: minimal scrapbook-style flatlays and OOTD entries, attractive combinations, easy recording, and shareable images.

Proposed visual treatment for D06: warm off-white surfaces, charcoal text, muted sage accents, generous spacing, readable text, garment images as the focus, and restrained paper-like details around diary compositions. Typography must remain legible at small sizes. Canvas controls must remain distinct from decorative content.

Git-tracked project content is English. Ignored local reading materials may use Chinese. The interface language is proposed as English; a different interface language remains available as a user decision without changing the tracked-file language rule.

## Features and Behavior

### Wardrobe Records

Source: scope.md > The POC Boundary.

Established requirements: garment image, category, color, brand, size, suitable seasons, purchase price, and purchase timing. Owned and potential items must be distinguishable so shopping ideas do not inflate the owned wardrobe.

Proposed supporting behavior: searchable image cards; filters for ownership, category, color, brand, and season; editable garment details; a user-controlled retirement action that preserves recorded history.

Acceptance criteria:

- Saving and reopening a garment preserves its image and entered attributes.
- Changing an attribute is reflected in the wardrobe and garment details.
- Owned and potential items remain visibly distinguishable.
- Filters show the matching saved records and a clear message when no records match.
- An item remains linked to its saved outfits and journal entries after an attribute update.

### Image Import and Automatic Tags

Source: scope.md > Inspiration & Identity, The POC Boundary.

Established requirements: import saved images, remove backgrounds automatically, and suggest tags.

Proposed supported inputs: PNG, JPEG, and WebP files selected from the device, dragged into the app, or pasted from the clipboard. Product URL scraping is not included as an assumed requirement. File input can contain a screenshot of a saved product image.

The import flow shows the original, processing status, cutout preview, and suggested labels. Users can correct model suggestions before saving. Tags are suggestions; brand, size, condition, price, and actual wear history must come from user input or a verified source. Missing metadata remains unknown.

Acceptance criteria:

- A real imported image produces a processed asset with an alpha channel and a visibly removed background.
- Tag suggestions are produced by the selected real image model and can be corrected.
- An incorrect suggestion does not overwrite a user's saved correction.
- Unreadable or unsupported input receives an actionable message and is not saved as a successful import.
- Failed processing preserves the import input for an explicit retry; the interface does not label the original as a completed cutout.

Exact automatic tag fields and model quality must be confirmed and verified under D02.

### Freeform Flatlay Composition

Source: scope.md > The Core Loop, The POC Boundary.

Established requirement: freely combine owned garments and potential purchases in a flatlay.

Proposed behavior: add cutouts to a canvas; move, resize, rotate, reorder, and remove layers; save and reopen compositions. Display owned and potential status in selection controls, leaving the exported composition visually clean.

Acceptance criteria:

- Both owned and potential garments can be added to the same composition.
- Moving, resizing, rotating, and reordering a layer changes the visible result.
- Saving and reopening restores positions, sizes, rotations, layer order, and the chosen images.
- Removing a layer from a composition leaves the underlying garment intact.
- An exported image matches the visible saved composition and includes its stickers.

### Purchase Decision Support

Source: scope.md > The Unique Kernel, The POC Boundary.

Established requirement: use existing clothes and potential items to help assess a purchase. The app must support the user's judgment.

Proposed calculation for D03: enter a candidate price and an estimated future wear count; show projected cost per wear separately from actual use. Display saved combinations that include the candidate so the user can inspect how it fits the wardrobe.

Acceptance criteria:

- A candidate remains separate from owned inventory until the user marks it purchased.
- Purchase assumptions are visibly labeled as estimates.
- Projected cost per wear uses the candidate's entered price and estimated wears.
- Saving and reopening a candidate preserves its projected wear estimate separately from actual wear records.
- Actual use metrics remain separate from purchase projections.
- The user can inspect compositions involving the candidate before deciding.

### Wear Records and Value

Source: scope.md > The Core Loop, The POC Boundary.

Established requirements: record or estimate wear count and duration; retain current condition; calculate average cost per wear; compare with personal cost and duration reference values.

Arithmetic: cost per wear = purchase price / total wears. Zero wears means cost per wear is unavailable. An unknown price remains unknown. Estimated values must remain identifiable as estimates.

Proposed behavior for D04: maintain an opening wear-count estimate for older garments, then add dated wear events. Display time since acquisition with an explicit label. If an actual first-worn date is supplied, display time since first use separately. Enter condition and notes manually.

Acceptance criteria:

- A garment costing 120 currency units with 12 total wears displays 10 units per wear.
- Zero recorded wears displays an explanatory empty value without division errors.
- Updating price or count updates cost per wear.
- Estimates are visible and distinguishable from individually recorded events.
- Estimated acquisition and first-use timing retain their stated precision; approximate duration does not appear as an exact anniversary fact.
- The app shows comparisons with the user's reference values without changing garment ownership or retirement status.
- Planned outfits do not count as actual wears. D04 will define the explicit action that records use.
- Different currencies are displayed explicitly; amounts in different currencies are not silently combined.

### OOTD Journal and Personalized Stickers

Source: scope.md > Inspiration & Identity, The POC Boundary.

Established requirements: scrapbook-style outfit diary and personalized character stickers.

Proposed behavior: select a date and saved composition, add a short note and a personalized sticker, then save and revisit the entry. Image export provides a shareable result. D05 defines how the character is customized or generated.

Acceptance criteria:

- A dated entry retains its composition, note, and selected sticker when reopened.
- The selected character reflects the user's chosen personalization method.
- Stickers can be positioned within the composition and appear in image export.
- Editing a saved outfit does not silently alter a previously saved diary image.
- Saving a planned entry does not silently record actual garment use.
- Repeated layers of one owned garment count as one garment when explicitly logging an outfit as worn. Date edits and deletion follow the confirmed D04 history policy.

### Brand Inspiration

Source: scope.md > The Core Loop, The POC Boundary.

Established requirement: record brands the user is curious about or wants to try.

Proposed behavior: save a brand name, website, interest notes, and optional inspiration image. Find these records again and associate them with wardrobe or candidate items.

Acceptance criteria:

- A saved brand and its notes remain available after reopening the app.
- Brand records can be edited without losing garment associations.
- A garment can refer to a saved brand while keeping user-entered garment metadata.

## States and Boundaries

- First use: the wardrobe, journal, and brand collection are empty with a clear action to add the relevant content. Do not invent a personal wardrobe or insert unlabeled demonstration data.
- Processing: show the actual pending image operation and retain unsaved form values.
- Validation errors: identify the affected field; preserve valid input. A wear count cannot be negative and a price cannot be negative.
- Processing failure: report failure honestly and support a deliberate retry. Do not substitute fabricated tags or a placeholder cutout.
- Persistence: saved garments, assets, compositions, diary entries, and brands survive an application restart.
- Retirement: the user initiates the decision; record history is preserved. This is separate from deleting a record.
- Deletion: proposed behavior is to block deletion of a garment referenced by a saved outfit or diary and offer retirement. D04 must confirm this policy.
- Currency: retain the currency on each monetary value. Cross-currency totals require a separately agreed conversion feature.
- Draft work: show unsaved changes before navigation would discard them. The PRD does not assume automatic publication or sharing.

## Product Decisions

Established by the learner:

- The creator is the first user.
- Tomorrow's outfit, decluttering, and potential purchases are the main entry situations.
- All proposed requirement areas matter and remain in scope.
- Flatlay composition is the chosen direction; virtual try-on is excluded.
- Cost, duration, and condition support personal decisions. The app does not make those decisions.
- Planning should proceed directly, with unresolved decisions collected for later review.
- Git-tracked project files must be English; ignored local reading materials can be Chinese and conversation can be multilingual.

The surface organization, input format details, projected purchase calculation, wear-event behavior, palette, interface language, and sticker workflow are proposals pending review.

## What We're Building

All seven behavior areas above, connected through shared garments and persisted data. Success requires real image processing, working composition, diary and sticker support, correct use calculations, purchasing support, and brand records. Each area must meet its acceptance criteria.

## Deferred From the POC

No requested capability has been approved for deferral. Accounts, cloud synchronization, URL scraping, automatic purchase execution, and direct social-network integrations have not been requested or selected; they are not implied implementation commitments.

## Non-Goals

Virtual try-on and automatic purchasing or retirement decisions, as explicitly established in scope.md > Explicitly Cut.

## Open Questions

- D01: native iOS architecture, Swift, device compatibility, and local persistence.
- D02: supported input scenes, garment isolation from person-worn images, automatic tag fields, and verified formats.
- D03: purchase support based on combinations and projected wear cost.
- D04: actual wear logging, estimated dates, duration meaning, and retirement/deletion behavior.
- D05: personalized character input, customization, and output.
- D06: visual direction, interface language, and review format.
- D07: license selection and public delivery authorization.

D01–D06 affect the product or implementation. D07 affects public licensing and publication. The technical specification elaborates these questions. No unanswered proposal is a completed or approved feature.
