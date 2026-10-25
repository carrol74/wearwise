---
doc: prd
status: approved
---

# Wearwise — Product Requirements

A personal wardrobe and scrapbook-style outfit journal for styling, buying, and decluttering decisions.

Sources: scope.md > The Unique Kernel, The Core Loop, The POC Boundary.

## The Core Journey

1. Import a standalone garment image from a product photo, saved web image, or personal flatlay.
2. Review a real cutout and color suggestions, select a category from basic options, then save its attributes.
3. Browse the wardrobe, which contains only garments the user already has, and select garments for an outfit.
4. Add a potential purchase through the separate Shopping flow, style it with wardrobe garments, and calculate its projected cost per wear using a temporary future-wear estimate. Explicitly add it to the wardrobe once the user has it.
5. Save a reusable outfit collage with an optional character sticker, or record a date and individual garments/saved outfit in Journal.
6. Explicitly record actual wearing and inspect count, duration, condition, and cost per wear.
7. Decide what to buy, retain, or retire. Retired garments disappear from the electronic wardrobe while their diary images and history remain.
8. Record and revisit interesting brands.

## Screens and Layout

| Surface | Purpose | Connections |
| --- | --- | --- |
| Wardrobe | Browse, filter, import, and edit garments the user already has | Garment details; flatlay composer |
| Shopping | Add and review potential purchases independently of the wardrobe | Shopping item details; flatlay composer; purchase calculator; explicit wardrobe transfer |
| Garment details | Attributes, actual use records, condition, reference values, and retirement | Wardrobe; retained history |
| Flatlay composer | Move, resize, rotate, and reorder garment and sticker layers | Saved outfits; diary; export |
| Outfit journal | Dated records of garments or saved outfits, notes, and read-only previews | Associated garments; automatic wearing on save |
| Brands | Names, links, notes, and inspiration | Garment associations |
| My character | Primary Wardrobe toolbar entry for appearance customization | Direct Save/Cancel return to Wardrobe; saved-character insertion in flatlays |

Retired records are excluded from wardrobe browsing, search, filter results, and new-composition selection. Historical diary content remains accessible.

## Look and Feel

Minimal scrapbook-style flatlays and OOTD. Use the supplied palette: white #FFFFFF and navy #355872. Navy anchors text and primary actions on white surfaces. Selected controls use solid navy fills, outlines, and checkmarks. Dark appearance uses a black page and navigation base, dark neutral cards and inputs, white text, and navy primary action accents; it does not fill the interface with blue. Garment images lead the composition; typography is readable and spacing is calm. Use native input and navigation controls styled with the application's palette.

Interface copy is English. Local planning notes are development artifacts and do not appear in the app.

## Features and Behavior

### Wardrobe Records

Source: scope.md > The POC Boundary.

Save an image, category, colors, brand, size, seasons, price/currency, acquisition timing, optional first-use timing, condition, and notes. Wardrobe import records garments the user already has. Condition is optional and describes physical wear: unknown, new, good, worn, or damaged. Actual use can be recorded without requiring a purchase.

Acceptance criteria:

- Reopening preserves images and entered attributes.
- Attribute edits update relevant views and filters.
- Garment and shopping details enter edit mode on the same page. Save commits the draft; Cancel preserves saved values. Retirement and deletion are direct icon actions within editing.
- Saved garment details provide actions to edit attributes, replace the image, and delete an unreferenced record.
- Image replacement uses the same import and review flow and preserves the garment identifier, attributes, and recorded use. New color suggestions require explicit acceptance before replacing existing values.
- Canceling or failing an image replacement preserves the current image. Successful replacement updates the current wardrobe image while existing saved compositions and diary snapshots retain their original assets.
- Deletion requires confirmation. Records without outfit, diary, or wear-history references are permanently deleted; referenced records leave the wardrobe through retirement while preserving history.
- Wardrobe import and attribute editing do not offer an Owned/Candidate status selector.
- Potential purchases remain outside wardrobe browsing, search, filters, and the wardrobe garment picker.
- Search/filter results match the saved records and show an empty state when needed.
- Retiring an item removes it from the wardrobe and new-outfit selection.
- Retirement preserves diary snapshots, retained assets, and recorded use.
- Retained diary entries stay readable after retirement.

### Image Import, Categories, and Colors

Source: scope.md > Inspiration & Identity, The POC Boundary.

Support standalone garment images through photo selection, file selection, explicit paste, and drag-and-drop. Person-worn photographs are outside this release. Verify supported PNG, JPEG, WebP, and photo-library encodings on the target OS.

Opening Photos requests the native iOS photo-library authorization when not yet determined. Support full access, selected-photo access, denial, and device restrictions. Browse authorized image assets inside the app. Limited access exposes Manage photos and Settings; denial exposes Open Settings without repeating the permission prompt. Refresh the visible library when access changes or the app returns from Settings. Imports, replacements, and brand references share this flow. Photo access is requested only when opening Photos. Files, paste, and image drop remain available without photo-library access.

Show the original, actual processing state, and transparent cutout. Users select categories from grouped basic options: tops, outerwear, bottoms, one-piece garments, shoes, bags/accessories, and underwear/swimwear. Suggest colors from visible garment pixels and allow dropdown multi-selection. Display selected colors as color swatches with text labels in import, editing, garment details, and wardrobe cards. Brand, size, seasons, price, condition, and wear history are user input. Unknown metadata stays unknown.

Acceptance criteria:

- Real supported garment images produce cutouts with visible background removal and transparency.
- Category selection is always available and uses garment types such as T-shirt, dress, or trousers.
- Real color analysis produces color suggestions that can be corrected through a dropdown.
- Selected colors display both their color swatch and text name; multiple colors and an unknown selection are supported.
- Corrected values persist and are not overwritten by subsequent display.
- Invalid input produces an actionable error and no successful garment record.
- A processing failure preserves the selected input for explicit retry.
- The original image is never represented as a completed cutout.

#### Cutout Quality and Review

Use a fixed set of at least twelve permitted, real standalone-garment images, with at least two examples in each group below. Review the original and actual cutout at normal card size, at 100% source-pixel scale, and on white, charcoal, and checkerboard backgrounds. Record each image separately on the physical iPhone. A successful API call or a nonempty alpha channel alone does not pass visual quality.

| Image group | Required inspection |
| --- | --- |
| Light garments on pale backgrounds | Preserve the complete garment silhouette without a visible background halo or erased hem/collar |
| Dark garments on dark or textured backgrounds | Retain sleeves and edges without merging the surrounding surface into the garment |
| Thin straps, ties, and narrow details | Keep visible straps/ties connected and preserve openings between them |
| Lace, mesh, and translucent fabric | Inspect holes and partial transparency against the original; record actual limitations instead of claiming opaque clipping is accurate |
| Patterned or multicolor garments | Preserve printed detail and separate background pixels; suggested colors remain editable |
| Standalone garments on cluttered backgrounds or in web screenshots | Exclude visible page/background objects and retain the selected garment; multiple garments may be rejected rather than separated |

- The user can inspect and reject a poor result before saving, retain the input for retry, or choose another image. A replacement rejection preserves the previously saved asset.
- Saving requires a deliberate user action after review. Failed extraction does not permit an original image to be labeled as a cutout.
- Every fixture receives a visual Pass/Fail and a recorded limitation where applicable. A failed representative case remains a release finding until corrected or its product boundary is explicitly resolved.
- Manual erase/restore tools are not currently implemented or promised. Whether to add manual repair remains an open product decision.

### Freeform Flatlay Composition

Source: scope.md > The Core Loop, The POC Boundary.

Add existing and candidate garments to a canvas. Move, resize, rotate, reorder, and remove layers. Save/reopen the complete arrangement. The editor also accepts personalized sticker layers.

Acceptance criteria:

- Existing and candidate garments can appear together.
- Every transform and layer-order action visibly changes the composition.
- The selected layer owns drag, pinch, rotation, and resize gestures. Other layers remain unchanged until deliberately selected. Four edge handles adjust width or height independently; four corner handles and pinch preserve the current aspect ratio. Handles use the rotated layer’s local axes and keep the opposite edge/corner anchored. Every completed interaction creates one undo step. Clip artwork and its shadows to the artboard in the editor, saved preview, and actual PNG. The selected sticker has a top-right X with a 44-point hit target, kept inside the artboard when near an edge. Removing a layer is undoable and preserves its underlying garment.
- Layers combines layer selection, order, size, independent width/height, rotation, and removal. Touch and hold a native row’s reorder handle to move it; the HTML reference supports a long press on the row. Ordering creates one undo step and preserves selection. There is no separate Adjust layer tool or canvas color palette. New work uses the existing white 1080×1350 artboard; older saved backgrounds and dimensions remain readable.
- Save/reopen restores dimensions, background, assets, transforms, and order.
- Removing a layer preserves the underlying garment.
- Retired garments remain visible in saved historical compositions and are unavailable for new selection.
- The exported image matches the composition, including stickers.
- New compositions use a fixed 1080×1350 canvas. Existing saved dimensions remain intact; no canvas-shape tool is shown.
- Undo and redo icons sit below the canvas at the left, above the main tool tray. Each completed gesture is one history step; layer insertion/removal and ordering can also be undone.
- The editor has one save action. A successful save closes the editor; a failed save retains the draft and displays the actual error.

### Purchase Decision Support

Source: scope.md > The Unique Kernel, The POC Boundary.

Shopping is a separate collection and entry path. Add a potential purchase image there, select its category, adjust colors, and record an optional listed price and notes. Open its details to style it with wardrobe garments and evaluate its price. Enter expected years of use, the number of seasons per year, and wearing frequency per week, month, or season. Convert these temporary inputs into estimated lifetime wears and divide the price by that count. The estimate is a one-time calculator input and is not saved as another wear-history record. Dismissing the calculator discards the estimate. Buying remains the user's decision.

Acceptance criteria:

- The calculator shows the entered price, years, seasons per year, wearing frequency, estimated total wears, and derived cost.
- A season uses thirteen weeks or three months. For three years, two seasons per year, and one wear per week, the estimate is 78 wears.
- Seasons per year range from one to four; years and wearing frequency must be positive whole numbers.
- Zero or invalid count receives clear feedback.
- Closing and reopening does not restore a previously entered future-wear estimate.
- A calculator session does not create wear events or require an eventual purchase.
- Saving a journal records actual wearing. An owned item can have unknown acquisition details and does not require a purchase record.
- Each candidate can keep multiple product URLs, store names, quoted prices, and currencies. Offers can be added, edited, deleted, and reopened.
- Quotes are manually entered; compare the lowest price only among offers in the same currency. Unknown prices remain unknown. No automatic exchange-rate or live-price claim is made.
- Shopping details have one icon-and-text Style primary action and a compact menu for purchase estimation, acquisition, and removal.
- The user can inspect candidate compositions before deciding.
- Shopping imports do not appear in the wardrobe or its garment picker. A separate shopping picker can add their images to a composition.
- Add to wardrobe is an explicit action after the user has the item. Review paid price/currency and acquisition date before confirming; retain the item identifier, images, attributes, history, and saved outfit references.
- Canceling or failing the transfer leaves the item in Shopping. Repeating a transfer cannot create a second wardrobe record.
- Removing a shopping item hides it from Shopping; referenced outfit images and history remain accessible.

### Wear Records and Value

Source: scope.md > The Core Loop, The POC Boundary.

Maintain an opening wear count for existing garments, with its estimate label when applicable, followed by dated actual wear events. Record condition and acquisition/first-use timing with precision. Display wear count, a compact elapsed-time summary, cost per wear, and an optional cost comparison using the Settings reference.

Cost per wear = entered price / cumulative actual wears. Unknown price or zero wears produces an unavailable value. Values derived from estimated historical counts retain that label. The temporary buying calculator does not become persistent future-use data.

Acceptance criteria:

- Price 120 and total wears 12 produces 10 per wear.
- Zero count and unknown price are handled explicitly.
- Price/count edits update results.
- Estimated opening history remains identifiable.
- Acquisition and first-use durations are labeled separately and preserve approximate date precision.
- Reference comparisons do not change garment status.
- Reusable outfits do not add wears until selected and saved in a journal entry.
- Repeated layers of one garment still count once per garment/calendar day.
- Repeated saves and multiple entries on one calendar day do not duplicate garment wears.
- Currency labels remain visible; different currencies are not silently combined.

### OOTD Journal and Personalized Stickers

Source: scope.md > Inspiration & Identity, The POC Boundary.

The Journal destination has Journal and Outfits collections. Outfits creates reusable freeform collages. Journal records a date, optional title, selected garments or a saved outfit, and an optional note through a simple form. An omitted title uses the date. Saving keeps an independent snapshot and PNG and records wearing in the same transaction. The form accepts today or past dates. One garment counts once per calendar day. Editing the date or selected pieces updates the matching wear records; deleting an entry removes only its unshared contribution. Existing historical snapshots remain readable. The form shows selected pieces only; Add pieces opens a searchable secondary picker with independent Done and Cancel actions.

Saved journal entries and outfits open in a read-only preview. Edit is a direct preview-header action. Each item’s ellipsis has a minimum 44-point target and contains Share image and deletion. Edit does not appear in this menu. Journal editing has no canvas or Share tool. Outfits retains the collage tools and sharing. Saved outfits are chosen explicitly from the journal form; Use today and Save as outfit are absent.

Open My character directly from the Wardrobe toolbar as a primary entry. It must not be nested inside Settings. Save and Cancel return to Wardrobe; changed drafts retain the existing discard confirmation. Character settings use six icon categories: Body, Arms, Legs, Hair, Face, and Beard. Seven silhouettes and six arm/leg builds combine with independent torso, shoulder, arm, and leg proportions. Total height stays fixed when torso length changes. Hair has 34 styles, including Bald, under Short, Medium, and Long tabs, custom base/accent colors, and Solid or Ombre treatments. New is a design-board preview filter only; iOS has exactly the three length groups and opens the saved hairstyle's group. Face settings include soft/balanced/defined structure, eight face shapes, twelve eye shapes, three eye sizes, custom iris color, four brow styles, eight noses, and eight mouth choices with three fullness levels. Expression is part of Mouth. Eight beard styles have an independent color picker. Skin uses presets and a full color picker. Accessories belong to garment collage layers. Preview changes, save the configuration, and insert the resulting transparent sticker into a composition.

Acceptance criteria:

- Reopened entries retain the date, note, snapshot, and sticker.
- Appearance changes visibly alter the illustrated two-dimensional character and persist after Save; Cancel preserves the saved configuration. Body, hairstyle, and facial choices use complete image previews; swatches represent colors. Option values are available through accessibility names without visible value chips.
- The outfit editor inserts the saved character directly, and previously saved diary layers retain their own character configuration.
- The character requires no personal photograph or external generation service.
- The approved style uses warm matte colors, refined facial features, and no black outlines. The base has fitted pale-gray clothing, compact charcoal shorts, and bare feet. Body changes affect only their named proportions; clothing follows the same body anchors.
- Hair keeps the head/face dimensions independent. Front and rear layers fit every supported face/structure without exposed scalp gaps, floating temples, covered eye corners, or ear-covering short sideburns. All twelve eye shapes retain visible iris regions responsive to the independent iris color. Review the actual contact sheets at face and sticker sizes.
- All eight added hairstyles remain in their length groups; the native editor has no New tab. Save/reopen restores the hairstyle and its group. Shag placement and Straight fringe face proportions must retain the approved fit.
- Stickers can be positioned and appear in exported images.
- Character and real garment cutouts are independent collage layers. Clothing retains its source perspective and is arranged through position, size, rotation, and order; generated garment illustration and automatic fitting are outside the agreed collage workflow.
- Editing the source outfit's dimensions, background, or layers leaves prior diary snapshots unchanged.
- All application confirmations and operation notices use compact centered toasts with no pointer or anchored popover. Retirement, deletion, and draft discard require explicit confirmation and never expire into an action. Cancel, tapping outside, or Escape preserves the current record or draft; every confirmation uses Cancel and Confirm button labels, with the action explained in its title and message. Ordinary result and error notices provide dismissal and disappear after seven seconds; native VoiceOver notices stay until dismissed. Long text remains scrollable, buttons retain 44-point touch targets, and large accessibility text can stack the actions. Confirmation callbacks retain the selected record until the action finishes and run once. System photo permissions, share controls, and selection menus retain their system behavior.
- Future-dated new journals are rejected; reusable outfits remain separate from actual wearing.
- Editing a journal date moves its wear contribution while preserving events shared by other entries.
- Editing selected pieces updates wear counts; the form has no separate recording/reversal action.
- Deleting a journal removes only its unshared wear contribution; unrelated and historically retained events remain.

### Brand Notes

Source: scope.md > The Core Loop, The POC Boundary.

Brands has one searchable list of saved brand notes and named owned brands. Every row opens the same profile. Record usual size, preferred materials, fit observations, typical price range/currency, and optional notes. Existing website and reference-image data remains readable. Inspirations uses the same counted expand/collapse control as Owned pieces. Multiple images are supported; editing uses a plus control to add photos and a top-right X on each photo to remove it. Saving commits image changes, while Cancel preserves the saved collection. Owned pieces are secondary inside a profile; candidate shopping pieces are managed in Shopping.

Acceptance criteria:

- Names are matched case-insensitively and appear once. There are no Owned/Discover tabs with different row interactions.
- Saving/reopening retains size, materials, fit, price range, and notes. A brand without a saved note can be opened from its owned garments and edited through the same profile.
- Editing or deleting saved brand notes preserves garment identities, brand names, images, and wear history.
- Manual brand records without owned pieces remain editable/deletable. Deleting notes for an owned brand leaves the derived owned-brand profile available.
- Website links use system controls. Changed drafts retain Save/Cancel and the centered discard confirmation.

## Capacity and Performance

Status: initial release acceptance targets; measurements are pending. These are benchmark workloads, not item-count limits. Supported data must never be silently truncated to satisfy a benchmark.

Use a physical iPhone SE (3rd generation) on iOS 18.4 as the compact baseline, or record an explicitly chosen replacement device/OS before measuring. Also execute the core journey on an available iOS 17 device before claiming minimum-OS acceptance. Test a release configuration without a debugger; record device, OS, build, image dimensions/bytes, library composition, timings, and peak memory.

| Workload | Initial acceptance target |
| --- | --- |
| Populated library | 1,000 wardrobe records, 200 candidates, 1,000 diaries, 100 saved outfits, 50 brands, and 5,000 wear events with real permitted image assets |
| Cold start | First usable wardrobe within 5 seconds; measure five cold launches and report the slowest |
| Browse, search/filter, and open a saved detail | 95th-percentile response within 2 seconds over twenty operations; correct complete results |
| Wardrobe scrolling and a 30-layer composition | At least 30 frames per second during ordinary interaction; each drag/pinch/rotation completes without a visible jump and creates one undo step |
| Import a local image up to 12 megapixels | Actual review ready within 20 seconds, excluding provider downloads; processing feedback appears within 1 second |
| Character preview change | Updated visible preview within 2 seconds; saved full-resolution export remains intact |
| Export a 1080×1350 composition with 30 image/sticker layers | PNG ready for the share sheet within 10 seconds, with matching dimensions, order, transparency, and background |

Measure larger phone photos separately. Define and report any required downsampling or input limit before implementation; retain reviewed image proportions and explicit errors. Run ten import/editor/open-close cycles and verify no memory termination or unbounded retained image growth. Record asset bytes before/after deletion, replacement, and temporary export cleanup; retained historical files must remain readable. Existing storage-full behavior must preserve committed records and retryable drafts. Device measurements determine any necessary optimization; no benchmark above is claimed as passed.

## Release Acceptance

- Run the connected physical-device route with the same garments: import and replace → Shopping comparison and acquisition → flatlay gestures and undo/redo → saved character → journal save and date/piece edits → retirement → brand notes and shopping quotes → PNG sharing and subsequent edited export → relaunch.
- Record outcomes per requirement and input variant, with the current build/device/OS, screenshots or logs, defects, and retest results. Include Photos/Files/Paste/drop, actual permission outcomes, and the configured target formats.
- Verify all required routes with large text, keyboard-open forms, light/dark appearance, reduced motion, and physical-device VoiceOver. Save/Cancel, errors, management actions, and dismissal must remain reachable.
- The creator completes the same core tasks without developer navigation assistance. Record completion, confusing controls, and resulting changes. Retest any issue that blocks a core task, hides state, or risks saved data before release acceptance.
- Complete performance cases alongside existing functionality. Component-test counts and browser snapshots cannot close an unexecuted device case. Current open checks remain listed in README.md.

## States and Boundaries

- First use: empty wardrobe, diary, and brand surfaces offer clear creation actions.
- Processing: reflect the actual operation and retain the draft.
- Input errors: identify invalid fields and retain valid input.
- Processing/storage failure: display the operation's error and preserve a retryable draft. No fabricated success, cutout, or tags.
- Persistence: saved garments, assets, outfits, diary entries, character preferences, and brands survive relaunch.
- Retirement: hide the garment from the electronic wardrobe while preserving diary snapshots and history.
- Deletion: confirm before permanently deleting an unreferenced garment. Referenced records cannot be permanently deleted; retirement remains available.
- Unsaved work: obtain a deliberate discard action before losing a draft.

## Product Decisions

- First user: the creator.
- Platform: native iOS with local data.
- All original product areas remain included.
- Person-worn photo processing is excluded from this release.
- Categories use manual basic choices. Only color tags are suggested automatically and remain editable.
- Pre-purchase estimates are temporary calculator inputs.
- Wearing does not require a purchase.
- Retirement removes an item from the wardrobe and retains diary content.
- Stickers use appearance-option personalization.
- Visual palette: white #FFFFFF and navy #355872 in light appearance; black #000000 and dark neutral surfaces with white text in dark appearance. Navy remains an action accent.
- Final buying and retirement choices remain with the user.

## What We're Building

Every behavior above, connected through saved garment records and immutable diary snapshots. Completion requires actual import processing, a working editor and journal, personalized stickers, correct use metrics, one-time buying calculations, and brand records.

## Deferred From the POC

Person-worn photograph processing. Other requested product areas remain included.

## Non-Goals

Virtual try-on, photo-generated characters, and automated buying or retirement decisions.

## Open Questions

Product decisions are resolved by the learner's consolidated confirmation. Manual cutout repair remains undecided; the current correction path is review, rejection, retry, or another image. Device image quality, format support, persistence, export, and capacity/performance targets require implementation evidence. Public publication, signing/account interaction, and submission actions require their corresponding authorization.

Garment cutout display areas use white in both appearances, including collection mounts, detail/import previews, journal piece thumbnails, brand-linked pieces, and garment pickers. This display background is separate from dark cards, fields, menus, and the saved collage background. Source image alpha and exported compositions remain unchanged.

Delete in garment editing always opens a confirmation toast. An unreferenced garment without wearing history is permanently deleted. A garment with outfit/journal references or wearing history is removed from the active wardrobe by retirement, preserving saved images and history. The confirmation explains retention; the control is not silently disabled.

Garment details show a compact Time summary (Owned for / In use for) only for known dates. Date controls and optional accuracy choices appear only while editing; read-only details do not show date-accuracy rows, duration ranges, or year-reference comparisons. Per-garment Personal references inputs are absent. Optional cost comparisons use Settings values. Existing stored dates, accuracy, and legacy reference values remain intact. Brand creation/editing fields retain visible titles and accessibility labels and contain no example or instructional placeholders.

Settings uses an inline searchable currency dropdown with explicit selection and a No currency option. The numeric goals are labeled Target cost per wear and Target years of use, without instructional helper paragraphs or Unset placeholders. The cost goal is an amount per wearing, not a total shopping budget; the use goal is the number of years the user hopes to wear a new garment. Existing saved values and calculation rules remain intact.
