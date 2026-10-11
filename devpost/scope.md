---
doc: scope
status: draft
---

# Wearwise

A personal wardrobe, flatlay styling, and decision-support app. See what you own, how items work together, and how much you use them, then decide what to buy, keep wearing, or retire.

## The Unique Kernel

Connect a visual wardrobe with flatlay outfits, wear history, and cost per wear. Each garment is both an image to compose and a personal item with a price, history, and condition. Potential purchases can be styled with existing clothes before buying; wear records inform later wardrobe decisions.

The app provides evidence. The user makes purchasing and retirement decisions. Reaching a personal value target does not automatically mean an item should be discarded.

## Who It's For

The first user is the creator, who opens Wearwise when planning tomorrow's outfit, decluttering, or considering a purchase. The problem is not knowing how many clothes they own, what to buy, or what to let go of. Their current alternatives have not been described.

## The Core Loop

Maintain the wardrobe → compose a flatlay with owned or potential items → save an outfit diary entry → record or estimate wear count, duration, and condition → inspect cost and personal reference values → decide what to keep, buy, or retire.

Collect brands the user is curious about or wants to try as a source of inspiration for future outfits and purchases. Return to the same wardrobe when getting dressed, shopping, or decluttering.

## Inspiration & Identity

Minimal scrapbook-style flatlays and OOTD entries: attractive compositions, low-effort recording, and shareable results. Personalized character stickers belong in the outfit diary. No specific reference products or URLs have been supplied.

Image import is a priority: saved product or web images should receive automatic background removal and tags.

## Why This Matters to the Learner

Bring personal wardrobe organization, styling, purchasing, and decluttering needs into one app while building taste and brand knowledge. The learning goal is to deepen understanding of the development process from zero to a product.

The learner considers all proposed requirements equally important and requests direct planning rather than speculative time estimates used to justify cuts.

## What "Working" Looks Like

A working prototype covering connected scenarios. The following demonstration route is proposed for review:

1. Import a garment image, process its background and tags, save its wardrobe record, and reopen it.
2. Browse existing clothes and freely compose a flatlay with owned items and a potential purchase.
3. Save the composition as a scrapbook-style OOTD entry with a personalized character sticker, then reopen it.
4. Enter or update price, dates, actual or estimated wear count, and condition. View duration, cost per wear, and personal reference values to inform a decision.
5. Save and revisit brands the user wants to try.

The key demonstration is continuity: the same garment participates in wardrobe organization, outfits, diary entries, and decisions informed by its use history.

## The POC Boundary

All proposed requirement areas remain in scope:

- Wardrobe records: image, category, color, brand, size, suitable seasons, purchase price, and purchase date.
- Image import: automatic background removal and tagging. The PRD will define supported inputs, quality expectations, and failure behavior.
- Freeform flatlay styling: combine existing clothes and potential purchases to support outfit planning and buying decisions.
- Use and value records: record or estimate duration and wear count; display cost per wear, personal monetary or duration reference values, and garment condition.
- Scrapbook-style OOTD: save diary entries, personalized character stickers, and shareable results. The PRD will define customization and sharing behavior.
- Brand inspiration: record brands the user is curious about or wants to try.

Build in dependency order: establish wardrobe records and image import, then flatlay composition. Connect diary entries, character stickers, wear history, and cost displays to those foundations, and complete brand collections. This sequence does not make later modules optional.

Scope defines the product boundary. The PRD will define behavior, exceptions, and acceptance criteria; the technical specification will validate implementation choices. Background removal, tagging, and character customization have not yet been technically validated. Placeholders or simulated outputs must not be presented as completed functionality.

## Later

No proposed requirement has been agreed for deferral. If a concrete limitation appears, explain its effect and revisit scope with the learner.

## Explicitly Cut

- Virtual try-on: explicitly removed by the learner in favor of flatlay composition.
- Automatic purchasing or retirement decisions: the learner wants decision support and retains the final choice.

## Submission Requirements

Based on the rules supplied by the learner: provide a public repository containing source, necessary assets, setup instructions, an open-source license, and scope.md, prd.md, and spec.md; provide a public demonstration video shorter than three minutes showing the running project; create the project during the submission period, disclose incorporated pre-existing work, and respect permissions for code, images, and other resources.

All repository files must be in English. Conversation may use multiple languages. Submission materials must be in English or include English translations. The full submission-period dates have not been verified.
