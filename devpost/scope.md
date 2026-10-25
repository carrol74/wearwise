---
doc: scope
status: approved
---

# Wearwise

A personal wardrobe, flatlay styling, and decision-support app. See what you own, how items work together, and how much you use them, then decide what to buy, keep wearing, or retire.

## The Unique Kernel

Connect a visual wardrobe with flatlay outfits, wear history, and cost per wear. Each garment is both an image to compose and a personal item with a price, history, and condition. Potential purchases can be styled with existing clothes before buying; wear records inform later wardrobe decisions.

The app provides evidence. The user makes purchasing and retirement decisions. Reaching a personal value target does not automatically mean an item should be discarded.

## Who It's For

The first user is the creator, who opens Wearwise when planning tomorrow's outfit, decluttering, or considering a purchase. The problem is not knowing how many clothes they own, what to buy, or what to let go of. Their current alternatives have not been described.

## The Core Loop

Maintain the wardrobe → compose a flatlay with owned or potential items → save a reusable outfit or record dated garment/outfit use → record or estimate wear count, duration, and condition → inspect cost and personal reference values → decide what to keep, buy, or retire.

Brands keeps personal notes about usual sizes, materials, fit, and price ranges in one consistent searchable list. Owned garments remain available under each profile. Shopping keeps candidate pieces with product links, website quotes, same-currency comparison, and acquisition. Wardrobe filters include brand.

## Inspiration & Identity

Minimal scrapbook-style flatlays and OOTD entries with the supplied white #FFFFFF and navy #355872 palette. My character is a primary entry on the Wardrobe toolbar. Independent character settings use six icon categories: Body, Arms, Legs, Hair, Face, and Beard. Accessories are separate garment collage layers. The character uses warm, matte illustration with refined facial details, no black outlines, a fitted neutral base, and bare feet. iOS groups all 34 hairstyles under Short, Medium, and Long; the design board alone has a New preview filter. Torso and limbs adjust separately, and all silhouettes support long/short hair and facial hair. Saved characters can be inserted into compositions. Clothing inputs contain standalone garments; person-worn photographs are excluded from this release.

Image import is a priority: saved product or web images receive automatic background removal and color suggestions. Users select garment categories from grouped basic options and adjust colors through a dropdown with visible color labels.

## Why This Matters to the Learner

Bring personal wardrobe organization, styling, purchasing, and decluttering needs into one app while building taste and brand knowledge. The learning goal is to deepen understanding of the development process from zero to a product.

The learner considers all proposed requirements equally important and requests direct planning rather than speculative time estimates used to justify cuts.

## What "Working" Looks Like

A working prototype covering connected scenarios. The following demonstration route is proposed for review:

1. Import a garment image, remove its background, review colors, select its category, save its wardrobe record, and reopen it.
2. Browse existing clothes and freely compose a flatlay with owned items and a potential purchase.
3. Save a reusable collage with a personalized character sticker. Choose worn garments or an owned saved outfit in Journal. Saving records wearing automatically; open its preview to edit the date, pieces, or notes.
4. Enter or update price, dates, actual or estimated wear count, and condition. View duration, cost per wear, and personal reference values to inform a decision.
5. Save and revisit brands the user wants to try.

The key demonstration is continuity: the same garment participates in wardrobe organization, outfits, diary entries, and decisions informed by its use history.

## The POC Boundary

The following agreed requirement areas remain in scope:

- Wardrobe records: image, category, color, brand, size, suitable seasons, purchase price, and purchase date.
- Shopping flow: import and evaluate potential purchases separately from the wardrobe, style them with existing garments, and explicitly add an item to the wardrobe once the user has it.
- Image import: automatic background removal and color suggestions, grouped manual category choices, and editable color labels. The PRD defines supported inputs, quality expectations, and failure behavior.
- Freeform flatlay styling: combine existing clothes and potential purchases to support outfit planning and buying decisions.
- Use and value records: record or estimate duration and wear count; display cost per wear, personal monetary or duration reference values, and garment condition.
- Outfits and Journal: create reusable collages with personalized character stickers; record dates, garments/saved outfits, and notes through a separate simple Journal form. Saved items open in preview with explicit Edit and menu-based sharing.
- Brand inspiration: record and delete saved brands, websites, inspiration, and separate fit/sizing/fabric observations. Interest is not an input.
- Release quality: inspect difficult garment cutouts, verify the connected physical-iPhone journey and accessibility, and measure capacity/performance against the PRD targets.

Build in dependency order: establish wardrobe records and image import, then flatlay composition. Connect diary entries, character stickers, wear history, and cost displays to those foundations, and complete brand collections. This sequence does not make later modules optional.

Scope defines the product boundary. The PRD defines behavior, exceptions, and acceptance criteria; the technical specification records implementation choices. Background removal and color suggestions have passed the learner's physical-iPhone checks. Appearance-option character customization and graphic choices are implemented with focused rendering, control, and persistence checks; integrated device acceptance remains pending.

## Completion Boundary

Core product modules and the current character artwork are implemented with focused verification. The new image-quality matrix and capacity/performance targets remain unverified. Connected physical-device acceptance, remaining gesture checks, VoiceOver, and user feedback remain open. A requirement or a passing component test does not establish completed release acceptance.

Manual cutout repair remains an open product decision; the current supported correction path is review, rejection, retry, or another image.

## Later

Person-worn photograph processing is deferred by the learner. All other requested product areas remain included.

## Explicitly Cut

- Virtual try-on: explicitly removed by the learner in favor of flatlay composition.
- Photo-based character generation: the learner chose appearance-option customization.
- Automatic purchasing or retirement decisions: the learner wants decision support and retains the final choice.

## Submission Requirements

Based on the rules supplied by the learner: provide a public repository containing source, necessary assets, setup instructions, an open-source license, and scope.md, prd.md, and spec.md; provide a public demonstration video shorter than three minutes showing the running project; create the project during the submission period, disclose incorporated pre-existing work, and respect permissions for code, images, and other resources.

Git-tracked project files must be in English. Ignored local reading materials may use Chinese. Conversation may use multiple languages. Submission materials must be in English or include English translations. The full submission-period dates have not been verified.
