# Wearwise

Personal wardrobe records, flatlay outfits, OOTD journals, use-value evidence, purchase support, and brand inspiration.

## Project Status

The product and technical plans are drafts. All requested product areas remain included. The current technical recommendation is a native iOS app. The iOS application target has not yet been implemented or verified.

The repository contains a Foundation-only Swift calculation package and its real-value tests. All 13 tests pass with Swift 6.4 (Apple Swift version 6.4, swiftlang-6.4.0.34.1) and Xcode 27.0 (Build 27A266a) installed under /Applications/Xcode.app.

## Planning Documents

- [Scope](devpost/scope.md): product purpose and complete requirement boundary.
- [Product requirements](devpost/prd.md): behaviors and observable acceptance criteria.
- [Technical specification](devpost/spec.md): proposed iOS architecture, data flow, and verification.
- [Build checklist](devpost/checklist.md): ordered working behaviors and checks.

The learner profile and local decision-review notes are ignored by Git. Product and technical documents contain their own open questions so the published plan remains complete.

## Calculation Package

WearwiseCore provides:

- Cost per wear from known prices and positive wear counts.
- Explicit unavailable results for unknown price or zero wears.
- Separate opening wear estimates and recorded wear counts.
- Comparison with personal cost references using unrounded values.
- Separate future-wear purchase projections.
- Exact-date duration and anniversary calculations using Calendar.

The package uses Swift 6 and Foundation. Tests use Swift Testing and cover decimal amounts, unknown values, negative input rejection, estimate labels, reference boundaries, and leap-year anniversaries.

With a consistent Swift toolchain installed, run from the repository root:

```sh
swift test --package-path packages/WearwiseCore
```

## iOS Development Requirements

The proposed application requires full Xcode, an iOS SDK, and an iOS 17-or-later target device. A physical iPhone is needed to validate actual image processing and personal-device installation. The complete run and signing instructions will be verified and added with the application target.

Current environment evidence: Swift 6.4 and Xcode 27.0 (Build 27A266a) are installed and active; the iOS simulator SDK is present. The core package tests pass.

## Curriculum Setup

Planning uses the [Devpost Learn Skill Pack](https://github.com/challengepost/learn-ai-basics). Locally installed skills are ignored by Git. skills-lock.json records their source and content hashes. Use the user's agents-kit workflow when managing local skills.

## Submission Preparation

The submitted repository must contain the planning documents, application source, permitted assets, installation instructions, and an open-source license. A public demonstration video must show the working app and remain shorter than three minutes under the supplied contest rules. License selection and public publication remain pending.
