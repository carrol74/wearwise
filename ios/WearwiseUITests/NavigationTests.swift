import XCTest

@MainActor
final class NavigationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func openPhotoAccess(_ app: XCUIApplication) {
        app.terminate()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        app.navigationBars.buttons["Import garment image"].tap()
        app.buttons["Choose from Library"].tap()
    }

    func testShoppingWebsitePasteExtractsTheProductLink() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Shopping"].tap()
        let item = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Shared link review")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        let product = "https://www.bestsecret.com/product.htm?code=40855905&colorCode=001327605&share=pdp"
        let editSaved = app.buttons["Edit website: Saved share"]
        for _ in 0..<8 where !editSaved.isHittable { app.swipeUp() }
        XCTAssertTrue(editSaved.isHittable)
        XCTAssertTrue(app.links["Open website"].exists || app.buttons["Open website"].exists)
        capture(app, "Legacy share text displays a compact website link")
        editSaved.tap()
        XCTAssertEqual(textValue(app.textFields["offer.website"]), product)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit website"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["toast.confirm"].exists)
        app.buttons["shopping.add-website"].tap()
        let retailer = app.textFields["offer.retailer"], storeName = "Pasted share " + UUID().uuidString.prefix(6)
        retailer.tap(); retailer.typeText(storeName)
        let website = app.textFields["offer.website"]
        website.tap(); website.press(forDuration: 1.1)
        let paste = nativeTextAction(app, "Paste")
        XCTAssertTrue(paste.waitForExistence(timeout: 5)); paste.tap()
        XCTAssertTrue(textValue(website).contains(product))
        XCTAssertTrue(textValue(website).contains("Register here:"))
        app.buttons["keyboard.done"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Add website"].waitForNonExistence(timeout: 5))
        let editPasted = app.buttons["Edit website: " + storeName]
        XCTAssertTrue(editPasted.waitForExistence(timeout: 5)); editPasted.tap()
        XCTAssertTrue(app.textFields["offer.website"].waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(app.textFields["offer.website"]), product)
        app.navigationBars.buttons["Cancel"].tap()
        capture(app, "Pasted product link is extracted and saved")
        app.terminate()
    }

    func testBrandSpacesRemainDuringTypingAndAfterSaving() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Brands"].tap()
        app.buttons["brands.add"].tap()
        let name = app.textFields["brand.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap()
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5)); name.tap()
        let fullName = "Massimo Dutti " + UUID().uuidString.prefix(6)
        name.typeText("Massimo")
        name.typeText(" ")
        XCTAssertEqual(textValue(name), "Massimo ")
        capture(app, "Brand name immediately after a space")
        name.typeText(String(fullName.dropFirst(8)))
        XCTAssertEqual(textValue(name), fullName)
        app.buttons["keyboard.done"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Add brand"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[fullName].waitForExistence(timeout: 5))
        app.tabBars.buttons["Wardrobe"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Grid review coat")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 5)); garment.tap()
        app.navigationBars.buttons["Edit"].tap()
        let brand = app.textFields["garment.brand"]
        replaceText(brand, with: "")
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5)); brand.tap()
        brand.typeText("Massimo")
        capture(app, "Garment brand before a space")
        brand.typeText(" ")
        XCTAssertEqual(textValue(brand), "Massimo ")
        capture(app, "Garment brand immediately after a space")
        brand.typeText("Dutti")
        XCTAssertEqual(textValue(brand), "Massimo Dutti")
        app.buttons["keyboard.done"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Brand, Massimo Dutti"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testPhotoGridCornerTapsSaveTheVisiblePhotos() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        let batch = String(UUID().uuidString.prefix(6))
        let positions: [CGVector] = [.init(dx: 0.5, dy: 0.5), .init(dx: 0.96, dy: 0.96),
            .init(dx: 0.04, dy: 0.96), .init(dx: 0.96, dy: 0.04), .init(dx: 0.04, dy: 0.04)]
        for (index, position) in positions.enumerated() {
            app.launch()
            app.tabBars.buttons["Brands"].tap()
            app.buttons["brands.add"].tap()
            let name = app.textFields["brand.name"], title = "Photo grid tap \(batch) \(index)"
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            name.tap()
            if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap(); name.tap() }
            XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5))
            name.tap()
            name.typeText(title)
            XCTAssertEqual(textValue(name), title)
            app.buttons["keyboard.done"].tap()
            let choose = app.buttons["brand.inspiration.add"]
            for _ in 0..<8 where !choose.isHittable { app.swipeUp() }
            XCTAssertTrue(choose.isHittable); choose.tap()
            let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = system.buttons["Allow Full Access"]
            let photo = app.buttons["photos.asset.\(index)"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in allow.exists || photo.exists }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
            if allow.exists { allow.tap() }
            XCTAssertTrue(photo.waitForExistence(timeout: 10))
            if index == 0 { capture(app, "Actual photo grid before tapping") }
            photo.coordinate(withNormalizedOffset: position).tap()
            XCTAssertTrue(app.images["brand.inspiration"].waitForExistence(timeout: 10))
            app.navigationBars.buttons["Save"].tap()
            XCTAssertTrue(app.navigationBars["Add brand"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    func testPhotoSelectionReturnsToImportAndFinishesProcessing() {
        let app = XCUIApplication()
        openPhotoAccess(app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = system.buttons["Allow Full Access"]
        let libraryReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            allow.exists || app.buttons["photos.asset.0"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [libraryReady], timeout: 30), .completed)
        if allow.exists { allow.tap() }
        let photo = app.buttons["photos.asset.0"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10)); photo.tap()
        let result = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.segmentedControls["import.preview"].exists || app.staticTexts["Import failed"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [result], timeout: 30), .completed,
            "Selecting a real photo must leave processing and show either cutout review or the actual extraction error.")
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(app.navigationBars["Photos"].exists)
        capture(app, "Photo selection processing result")
        if app.segmentedControls["import.preview"].exists {
            app.navigationBars.buttons["Cancel"].tap(); app.buttons["toast.confirm"].tap()
        } else {
            XCTAssertTrue(app.buttons["Retry selected image"].exists)
            app.buttons["toast.dismiss"].tap(); app.navigationBars.buttons["Cancel"].tap()
        }
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testPhotoLibraryFullAccessUsesAppGrid() {
        let app = XCUIApplication()
        openPhotoAccess(app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = system.buttons["Allow Full Access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 8)); allow.tap()
        XCTAssertTrue(app.buttons["photos.asset.0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["photos.manage"].exists)
        capture(app, "Full photo access shows the app photo grid")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testBrandInspirationPersistsAndExpandsInProfile() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Brands"].tap(); app.buttons["brands.add"].tap()
        let name = "Inspiration review " + String(UUID().uuidString.filter(\.isLetter).prefix(6)).lowercased()
        let field = app.textFields["brand.name"]
        field.tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap(); field.tap() }
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5)); field.tap()
        field.typeText(name)
        XCTAssertEqual(textValue(field), name)
        app.buttons["keyboard.done"].tap()
        let choose = app.buttons["brand.inspiration.add"]
        let images = app.images.matching(identifier: "brand.inspiration")
        let removals = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "brand.inspiration.remove."))
        for index in 0..<3 {
            for _ in 0..<7 where !choose.isHittable { app.swipeUp() }
            XCTAssertTrue(choose.isHittable); choose.tap()
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow Full Access"]
            let photo = app.buttons["photos.asset.\(index)"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in allow.exists || photo.exists }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
            if allow.exists { allow.tap() }
            XCTAssertTrue(photo.waitForExistence(timeout: 10)); photo.tap()
            XCTAssertTrue(app.buttons["Inspirations (\(index + 1))"].waitForExistence(timeout: 8))
        }
        capture(app, "Multiple inspiration photos in the brand draft with plus and X controls")
        removals.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Inspirations (2)"].exists)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Add brand"].waitForNonExistence(timeout: 5))
        let profile = app.buttons["brands.profile." + name.lowercased()]
        XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
        let disclosure = app.buttons["Inspirations (2)"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        let image = app.descendants(matching: .any).matching(identifier: "brand.inspiration").firstMatch
        XCTAssertFalse(image.isHittable)
        capture(app, "Saved brand inspiration starts collapsed")
        disclosure.tap()
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        for _ in 0..<4 where !image.isHittable { app.swipeUp() }
        XCTAssertTrue(image.isHittable)
        capture(app, "Saved brand inspiration expands to show the selected photo")
        disclosure.tap()
        XCTAssertFalse(image.isHittable)
        app.navigationBars.buttons["Edit"].tap()
        let firstRemove = removals.element(boundBy: 0)
        for _ in 0..<5 where !firstRemove.isHittable { app.swipeUp() }
        XCTAssertTrue(firstRemove.isHittable); firstRemove.tap()
        XCTAssertTrue(app.buttons["Inspirations (1)"].exists)
        app.navigationBars.buttons["Cancel"].tap(); app.buttons["toast.confirm"].tap()
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        app.navigationBars.buttons["Edit"].tap()
        for _ in 0..<5 where !firstRemove.isHittable { app.swipeUp() }
        firstRemove.tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Inspirations (1)"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["Brands"].tap()
        XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
        let savedDisclosure = app.buttons["Inspirations (1)"]
        XCTAssertTrue(savedDisclosure.waitForExistence(timeout: 5)); savedDisclosure.tap()
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertTrue(image.isHittable)
        XCTAssertEqual(images.count, 1)
        capture(app, "One saved inspiration remains after removal and app relaunch")
        app.terminate()
    }

    func testPhotoLibraryDeniedShowsSettingsWithoutRepeatingPrompt() {
        let app = XCUIApplication()
        openPhotoAccess(app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = system.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 8)); deny.tap()
        XCTAssertTrue(app.buttons["photos.settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["photos.asset.0"].exists)
        capture(app, "Denied photo access offers Settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Choose from Library"].tap()
        XCTAssertTrue(app.buttons["photos.settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(system.buttons["Allow Full Access"].exists)
        app.terminate()
    }

    func testManagePhotosOpensAndCancelsWithoutAnotherSheet() {
        let app = XCUIApplication()
        openPhotoAccess(app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let limited = system.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Select Photos", "Limit Access")).firstMatch
        XCTAssertTrue(limited.waitForExistence(timeout: 8)); limited.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 15))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["photos.manage"].waitForExistence(timeout: 8))
        for attempt in 1...2 {
            app.buttons["photos.manage"].tap()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 15))
            XCTAssertEqual(app.state, .runningForeground)
            capture(app, "Manage photos opens the system selection manager \(attempt)")
            app.buttons["Cancel"].tap()
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["photos.manage"])
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            XCTAssertTrue(app.navigationBars["Photos"].exists)
        }
        app.navigationBars["Photos"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Choose from Library"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testPhotoLibraryLimitedAccessShowsOnlySelection() {
        let app = XCUIApplication()
        openPhotoAccess(app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let limited = system.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Select Photos", "Limit Access")).firstMatch
        XCTAssertTrue(limited.waitForExistence(timeout: 8)); limited.tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8))
        for selected in app.images.matching(identifier: "PXGGridLayout-Info").allElementsBoundByIndex where selected.isSelected { selected.tap() }
        photo.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["photos.manage"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["photos.asset.0"].exists)
        XCTAssertFalse(app.buttons["photos.asset.1"].exists)
        XCTAssertGreaterThanOrEqual(app.buttons["photos.manage"].frame.height, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["photos.settings"].frame.height, 44)
        capture(app, "Limited photo access shows only the authorized photo")
        app.buttons["photos.manage"].tap()
        let additional = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(additional.waitForExistence(timeout: 8)); additional.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["photos.asset.1"].waitForExistence(timeout: 8))
        capture(app, "Managing limited access adds the newly authorized photo")
        app.buttons["photos.manage"].tap()
        let first = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 8)); first.tap()
        app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["No photos selected"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["photos.asset.0"].exists)
        capture(app, "Revoking the selected photos clears the app grid")
        for attempt in 1...2 {
            app.buttons["photos.manage"].tap()
            XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 8))
            capture(app, "System photo manager directly above the app browser \(attempt)")
            app.buttons["Cancel"].tap()
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["photos.manage"])
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            XCTAssertTrue(app.navigationBars["Photos"].exists)
        }
        capture(app, "Cancel returns directly to the existing photo browser")
        app.navigationBars["Photos"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Choose from Library"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testReplacementOpensAppPhotoBrowserAndCancelsWithoutChanges() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Inline review tee")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 8)); garment.tap()
        app.navigationBars.buttons["Edit"].tap(); app.buttons["Replace image"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["photos.manage"].exists)
        app.navigationBars["Photos"].buttons.element(boundBy: 0).tap()
        app.navigationBars["Replace Image"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Inline review tee"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Replace image"].exists)
        app.terminate()
    }

    func testDeleteItemsWithTheirOwnImagesDoesNotCrash() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Delete unique images")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 8)); garment.tap()
        app.navigationBars.buttons["Edit"].tap()
        app.buttons["garment.delete"].tap()
        XCTAssertTrue(app.buttons["toast.confirm"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["toast.confirm"].label, "Confirm")
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(garment.exists)
        app.tabBars.buttons["Shopping"].tap()
        let candidate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Remove unique shopping images")).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 8)); candidate.tap()
        app.navigationBars.buttons["Remove shopping item"].tap()
        XCTAssertTrue(app.buttons["toast.confirm"].waitForExistence(timeout: 5))
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(candidate.exists)
        app.terminate(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap(); XCTAssertFalse(garment.exists)
        app.tabBars.buttons["Shopping"].tap(); XCTAssertFalse(candidate.exists)
        app.terminate()
    }

    func testSimplifiedGarmentTimeAndBrandFields() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Details review tee")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 8)); garment.tap()
        for _ in 0..<8 where !app.staticTexts["Owned for"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Owned for"].exists)
        XCTAssertTrue(app.staticTexts["In use for"].exists)
        XCTAssertFalse(app.staticTexts["Personal references"].exists)
        XCTAssertFalse(app.staticTexts["Acquired precision"].exists)
        XCTAssertEqual(app.datePickers.count, 0)
        capture(app, "Compact owned and in-use time summary")
        app.navigationBars.buttons["Edit"].tap()
        let accuracy = app.descendants(matching: .any).matching(identifier: "garment.dateAccuracy.Acquired").firstMatch
        for _ in 0..<8 where !accuracy.exists { app.swipeUp() }
        XCTAssertTrue(accuracy.exists)
        XCTAssertFalse(app.textFields["garment.costReference"].exists)
        XCTAssertFalse(app.textFields["garment.yearReference"].exists)
        capture(app, "Date accuracy stays inside editing and per-item references are absent")
        app.navigationBars.buttons["Cancel"].tap()
        app.tabBars.buttons["Brands"].tap(); app.buttons["brands.add"].tap()
        for identifier in ["brand.fit", "brand.sizing", "brand.fabric", "brand.price", "brand.notes"] {
            let field = app.textFields[identifier]
            for _ in 0..<7 where !field.exists { app.swipeUp() }
            XCTAssertTrue(field.exists)
            XCTAssertTrue((field.placeholderValue ?? "").isEmpty)
        }
        capture(app, "Brand fields use titles without example placeholders")
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testGarmentDeleteWorksWithAndWithoutHistory() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        capture(app, "White garment image mounts on the black wardrobe")
        for (name, keepsHistory) in [("Inline review tee", false), ("Toast journal tee", true)] {
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
            app.navigationBars.buttons["Edit"].tap()
            let deletion = app.buttons["garment.delete"]
            XCTAssertTrue(deletion.waitForExistence(timeout: 5)); XCTAssertTrue(deletion.isEnabled)
            deletion.tap()
            XCTAssertTrue(app.buttons["toast.confirm"].waitForExistence(timeout: 5))
            if keepsHistory {
                XCTAssertTrue(app.staticTexts["This removes the garment from your wardrobe. Saved outfits, journal images, and wearing history will remain."].exists)
            }
            capture(app, keepsHistory ? "Delete referenced garment preserves history" : "Delete an unreferenced garment")
            app.buttons["toast.cancel"].tap()
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["garment.delete"])
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            app.buttons["garment.delete"].tap(); app.buttons["toast.confirm"].tap()
            XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists)
        }
        app.terminate(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Inline review tee")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Toast journal tee")).firstMatch.exists)
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["View diary entry: Toast review diary"].waitForExistence(timeout: 8))
        app.buttons["View diary entry: Toast review diary"].tap()
        XCTAssertTrue(app.buttons["journal.preview.edit"].waitForExistence(timeout: 5))
        capture(app, "Journal snapshot survives deleting its garment from the wardrobe")
        app.navigationBars["Journal entry"].buttons["Close"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertTrue(app.buttons["View outfit: Toast review outfit"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testToastGarmentDeleteCancelAndRetirementConfirm() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Inline review tee")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 8)); garment.tap()
        app.navigationBars.buttons["Edit"].tap()
        let retirement = app.buttons["garment.retire"]
        for _ in 0..<15 where !retirement.isHittable { app.swipeUp() }
        XCTAssertTrue(retirement.isHittable)
        app.buttons["garment.delete"].tap()
        XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Delete Inline review tee?"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "toast.confirmation").firstMatch.exists)
        capture(app, "Centered garment deletion toast in dark appearance")
        app.buttons["toast.cancel"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["toast.cancel"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["garment.retire"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        app.buttons["garment.retire"].tap()
        XCTAssertTrue(app.staticTexts["Retire Inline review tee?"].waitForExistence(timeout: 5))
        capture(app, "Centered retirement toast in dark appearance")
        app.buttons["toast.cancel"].tap()
        let readyAgain = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["garment.retire"])
        XCTAssertEqual(XCTWaiter.wait(for: [readyAgain], timeout: 5), .completed)
        app.buttons["garment.retire"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Inline review tee")).firstMatch.exists)
        app.terminate()
    }

    func testToastBrandCancelAndConfirmPreserveSelection() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Brands"].tap()
        app.buttons["brands.add"].tap()
        let name = "Toast review " + UUID().uuidString.prefix(6)
        replaceText(app.textFields["brand.name"], with: name)
        app.navigationBars.buttons["Save"].tap()
        let row = app.buttons["brands.profile." + name.lowercased()]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["brand.delete"].tap()
        XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "toast.confirmation").firstMatch.exists)
        capture(app, "Centered brand deletion toast")
        app.buttons["toast.cancel"].tap()
        XCTAssertTrue(app.buttons["brand.delete"].isHittable)
        app.buttons["brand.delete"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.terminate()
    }

    func testToastDiscardAtLargestTextSizeKeepsDraft() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Brands"].tap()
        app.buttons["brands.add"].tap()
        replaceText(app.textFields["brand.name"], with: "Unsaved toast draft")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
        let confirm = app.buttons["toast.confirm"]
        XCTAssertTrue(confirm.isHittable)
        XCTAssertGreaterThanOrEqual(confirm.frame.minX, app.frame.minX + 12)
        XCTAssertLessThanOrEqual(confirm.frame.maxX, app.frame.maxX - 12)
        capture(app, "Largest text discard toast with both choices reachable")
        app.buttons["toast.cancel"].tap()
        XCTAssertEqual(textValue(app.textFields["brand.name"]), "Unsaved toast draft")
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testToastJournalAndOutfitDeleteTheSelectedRecord() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        for (section, name, kind, action) in [
            ("Journal", "Toast review diary", "Diary", "Delete entry"),
            ("Outfits", "Toast review outfit", "Outfit", "Delete outfit")
        ] {
            app.segmentedControls.buttons[section].tap()
            let menu = app.buttons["\(kind) actions: \(name)"]
            XCTAssertTrue(menu.waitForExistence(timeout: 8)); menu.tap()
            app.buttons[action].tap()
            XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
            capture(app, "\(kind) deletion toast keeps the selected record")
            app.buttons["toast.cancel"].tap()
            XCTAssertTrue(menu.exists)
            menu.tap(); app.buttons[action].tap()
            app.buttons["toast.confirm"].tap()
            XCTAssertFalse(menu.exists)
        }
        app.terminate()
    }

    func testToastShoppingRemovalCancelAndConfirm() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Shopping"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Inline shopping review")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        let remove = app.buttons["Remove shopping item"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5)); remove.tap()
        XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
        capture(app, "Shopping removal uses the shared toast")
        app.buttons["toast.cancel"].tap()
        XCTAssertTrue(remove.isHittable)
        remove.tap(); app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.terminate()
    }

    func testSelectedLayerResizeDeleteAndLongPressOrdering() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        app.buttons["Character"].tap()
        app.buttons["Character"].tap()
        let layers = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "outfit.layer.", ", layer "))
        let canvasCenter = selectedLayerCenter(app)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Canvas layer accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertEqual(layers.count, 2)
        let first = layers.element(boundBy: 0), selected = layers.element(boundBy: 1)
        let untouched = first.value as? String, before = selected.value as? String
        let handle = app.descendants(matching: .any).matching(identifier: "layer.resize.right").firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let origin = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 25, dy: 0)))
        XCTAssertNotEqual(selected.value as? String, before)
        XCTAssertEqual(first.value as? String, untouched)
        app.buttons["outfit.undo"].tap()
        XCTAssertEqual(selected.value as? String, before)
        app.buttons["outfit.redo"].tap()
        let beforeCorner = selected.value as? String
        let corner = app.descendants(matching: .any).matching(identifier: "layer.resize.topLeft").firstMatch
        let cornerPoint = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        cornerPoint.press(forDuration: 0.05, thenDragTo: cornerPoint.withOffset(CGVector(dx: -12, dy: -12)))
        XCTAssertNotEqual(selected.value as? String, beforeCorner)
        XCTAssertEqual(first.value as? String, untouched)
        app.buttons["outfit.undo"].tap()
        XCTAssertEqual(selected.value as? String, beforeCorner)
        canvasCenter.press(forDuration: 0.05, thenDragTo: canvasCenter.withOffset(CGVector(dx: 60, dy: 0)))
        let otherPosition = selected.value as? String
        canvasCenter.withOffset(CGVector(dx: -20, dy: 0)).tap()
        XCTAssertTrue(first.isSelected)
        let firstPosition = first.value as? String
        canvasCenter.press(forDuration: 0.05, thenDragTo: canvasCenter.withOffset(CGVector(dx: -15, dy: 15)))
        XCTAssertNotEqual(first.value as? String, firstPosition)
        XCTAssertEqual(selected.value as? String, otherPosition)
        app.buttons["Layers"].tap()
        XCTAssertTrue(app.sliders["Layer rotation"].exists)
        XCTAssertFalse(app.navigationBars["Adjust layer"].exists)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "layers.row."))
        XCTAssertEqual(rows.count, 2)
        let topID = rows.element(boundBy: 0).identifier
        let dragStart = rows.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5))
        let dragEnd = rows.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.85))
        dragStart.press(forDuration: 1, thenDragTo: dragEnd)
        let reordered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "identifier != %@", topID), object: rows.element(boundBy: 0))
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: 5), .completed)
        XCTAssertNotEqual(rows.element(boundBy: 0).identifier, topID)
        capture(app, "Integrated Layers controls and reordered layers")
        app.navigationBars["Layers"].buttons["Done"].tap()
        app.buttons["layer.delete"].tap()
        XCTAssertEqual(layers.count, 1)
        XCTAssertFalse(app.buttons["Background"].exists)
        XCTAssertFalse(app.buttons["Adjust"].exists)
        capture(app, "Selected layer resize handles and delete control")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
        capture(app, "Centered discard confirmation")
        app.buttons["toast.cancel"].tap()
        XCTAssertTrue(app.buttons["Layers"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        app.terminate()
    }

    func testJournalRecordsOpenInPreviewAndHaveNoCollageTools() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Journal"].tap()
        app.buttons["journal.create"].tap()
        let name = "Record review \(UUID().uuidString.prefix(6))"
        replaceText(app.textFields["journal.name"], with: name)
        app.textFields["journal.name"].typeText("\n")
        app.buttons["journal.add-pieces"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "journal.piece.", "Inline review tee")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 5))
        for _ in 0..<5 where !garment.isHittable { app.swipeUp() }
        garment.tap()
        XCTAssertEqual(garment.value as? String, "Selected")
        app.navigationBars["Choose pieces"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].isEnabled)
        XCTAssertFalse(app.buttons["Share image"].exists)
        XCTAssertFalse(app.buttons["Layers"].exists)
        app.navigationBars.buttons["Save"].tap()
        let row = app.buttons["View diary entry: \(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let more = app.buttons["Diary actions: \(name)"]
        XCTAssertGreaterThanOrEqual(more.frame.width, 44)
        XCTAssertGreaterThanOrEqual(more.frame.height, 44)
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Share image"].exists)
        XCTAssertFalse(app.buttons["Edit"].exists)
        app.buttons["Share image"].tap()
        let shareClose = app.buttons["header.closeButton"]
        XCTAssertTrue(shareClose.waitForExistence(timeout: 10))
        capture(app, "Journal menu opens the real image share sheet")
        shareClose.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["journal.preview.edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["journal.name"].exists)
        XCTAssertFalse(app.buttons["Record wearing"].exists)
        XCTAssertFalse(app.buttons["Undo wearing"].exists)
        XCTAssertFalse(app.buttons["Save as outfit"].exists)
        capture(app, "Journal record preview with actual wearing")
        app.buttons["journal.preview.edit"].tap()
        XCTAssertTrue(app.textFields["journal.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["journal.add-pieces"].exists)
        XCTAssertFalse(app.buttons["Share image"].exists)
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars["Journal entry"].buttons["Close"].tap()
        app.terminate()
    }

    func testBrandWearFieldsPersistAndSavedBrandCanBeDeleted() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Brands"].tap()
        app.buttons["brands.add"].tap()
        let name = "Wear notes \(UUID().uuidString.prefix(6))"
        replaceText(app.textFields["brand.name"], with: name)
        XCTAssertFalse(app.pickers["Interest"].exists)
        for (id, value) in [("brand.fit", "Relaxed"), ("brand.sizing", "Size M"), ("brand.fabric", "Cotton"), ("brand.price", "EUR 50–100") ] {
            let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
            for _ in 0..<6 where !field.isHittable { app.swipeUp() }
            replaceText(field, with: value)
        }
        capture(app, "Separate fit sizing and fabric fields")
        app.navigationBars.buttons["Save"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.buttons["brand.delete"].waitForExistence(timeout: 5))
        capture(app, "Saved brand wear notes")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Relaxed")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Size M")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Cotton")).firstMatch.exists)
        app.buttons["brand.delete"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists)
        app.terminate()
    }



    func testOutfitGestureHistoryAndSaveClosesEditor() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        let name = "Gesture review \(UUID().uuidString.prefix(6))"
        replaceText(app.textFields["outfit.name"], with: name)
        app.buttons["Character"].tap()
        let undo = app.buttons["outfit.undo"]
        let redo = app.buttons["outfit.redo"]
        XCTAssertTrue(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)
        undo.tap()
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        redo.tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 5))
        app.buttons["Layers"].tap()
        let size = app.sliders["Layer size"]
        for _ in 0..<6 where !size.isHittable { app.swipeUp() }
        size.adjust(toNormalizedSliderPosition: 0.35)
        app.navigationBars["Layers"].buttons["Done"].tap()
        let layer = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "outfit.layer.", ", layer ")).firstMatch
        XCTAssertTrue(layer.waitForExistence(timeout: 5))
        let original = layer.value as? String
        let center = selectedLayerCenter(app)
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 15, dy: 15)))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertNotEqual(layer.value as? String, original)
        undo.tap()
        XCTAssertEqual(layer.value as? String, original)
        redo.tap()
        let beforeScale = layer.value as? String
        layer.pinch(withScale: 1.25, velocity: 1)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let scaled = layer.value as? String
        XCTAssertNotEqual(scaled, beforeScale)
        undo.tap()
        XCTAssertEqual(layer.value as? String, beforeScale)
        redo.tap()
        XCTAssertEqual(layer.value as? String, scaled)
        layer.rotate(.pi / 8, withVelocity: 1)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertNotEqual(layer.value as? String, scaled)
        capture(app, "Icon editor after real drag pinch and rotation")
        XCTAssertFalse(app.buttons["Canvas"].exists)
        XCTAssertFalse(app.navigationBars["Outfit"].buttons["Done"].exists)
        app.navigationBars.buttons["Save"].tap()
        let entry = app.buttons["View outfit: \(name)"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.buttons["outfit.preview.edit"].waitForExistence(timeout: 5))
        app.buttons["outfit.preview.edit"].tap()
        XCTAssertEqual(app.textFields["outfit.name"].value as? String, name)
        XCTAssertFalse(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars["Outfit preview"].buttons["Close"].tap()
        deleteJournalRow(app, button: "View outfit: \(name)", confirmation: "Delete outfit")
        app.terminate()
    }

    func testCompactColorFiltersApplyAndClose() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        app.buttons["Filters"].tap()
        XCTAssertFalse(app.switches["Black"].exists)
        app.buttons["Adjust colors"].tap()
        XCTAssertTrue(app.buttons["Black"].waitForExistence(timeout: 5))
        app.buttons["Black"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.90)).tap()
        app.navigationBars.buttons["Apply"].tap()
        XCTAssertTrue(app.navigationBars["Filters"].waitForNonExistence(timeout: 5))
        capture(app, "Compact color filters applied through icon actions")
        app.terminate()
    }

    func testInlineGarmentEditingPersistsAndDiscards() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        let garment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Inline review tee")).firstMatch
        XCTAssertTrue(garment.waitForExistence(timeout: 5))
        garment.tap()
        XCTAssertFalse(app.buttons["Manage garment"].exists)
        app.navigationBars.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Inline review tee"].exists)
        XCTAssertFalse(app.navigationBars["Edit Garment"].exists)
        replaceText(app.textFields["garment.name"], with: "Edited review tee")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Edited review tee"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Edit"].tap()
        replaceText(app.textFields["garment.brand"], with: "Unsaved brand")
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.staticTexts["Review brand"].exists)
        capture(app, "Inline garment editor saved and discarded through icon actions")
        app.navigationBars.buttons["Edit"].tap()
        let delete = app.buttons["Delete garment"]
        for _ in 0..<8 { if delete.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        app.buttons["Delete garment"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testJournalRecordSaveExitsAndReopens() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Journal"].tap()
        app.buttons["journal.create"].tap()
        let name = "Saved record \(UUID().uuidString.prefix(6))"
        replaceText(app.textFields["journal.name"], with: name)
        app.textFields["journal.name"].typeText("\n")
        app.buttons["journal.add-pieces"].tap()
        let piece = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "journal.piece.", "Inline review tee")).firstMatch
        for _ in 0..<5 where !piece.isHittable { app.swipeUp() }
        piece.tap()
        app.navigationBars["Choose pieces"].buttons["Done"].tap()
        XCTAssertFalse(app.buttons["Layers"].exists)
        XCTAssertFalse(app.buttons["Share image"].exists)
        app.navigationBars.buttons["Save"].tap()
        let row = app.buttons["View diary entry: \(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.buttons["journal.preview.edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["journal.name"].exists)
        app.buttons["journal.preview.edit"].tap()
        XCTAssertTrue(app.textFields["journal.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(app.textFields["journal.name"]), name)
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars["Journal entry"].buttons["Close"].tap()
        deleteJournalRow(app, button: "View diary entry: \(name)", confirmation: "Delete entry")
        app.terminate()
    }

    func testPreferencesCurrencySearchAndDiscardDraft() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        openGarmentDefaults(app)
        let currency = app.buttons["preferences.currency"]
        let original = currency.value as? String
        XCTAssertEqual(app.textFields["preferences.cost"].placeholderValue ?? "", "")
        XCTAssertEqual(app.textFields["preferences.years"].placeholderValue ?? "", "")
        XCTAssertTrue(app.staticTexts["Target cost per wear"].exists)
        XCTAssertTrue(app.staticTexts["Target years of use"].exists)
        currency.tap()
        let search = app.textFields["preferences.currency.search"]
        replaceText(search, with: "123notacurrency")
        XCTAssertTrue(app.staticTexts["No currencies found"].waitForExistence(timeout: 5))
        XCTAssertEqual(currency.value as? String, original)
        replaceText(search, with: "Swedish")
        let sek = app.buttons["preferences.currency.option.SEK"]
        XCTAssertTrue(sek.waitForExistence(timeout: 5))
        capture(app, "Search currencies by name inside Settings")
        sek.tap()
        XCTAssertEqual(currency.value as? String, "SEK")
        XCTAssertFalse(search.exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        openGarmentDefaults(app)
        XCTAssertEqual(currency.value as? String, original)
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testPasteImportLeavesProcessingAndCanRetryOrReview() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        app.navigationBars.buttons["Import garment image"].tap()
        app.buttons["Paste image"].tap()
        func waitForProcessingResult() {
            let result = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.segmentedControls["import.preview"].exists || app.staticTexts["Import failed"].exists
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [result], timeout: 30), .completed,
                "Processing must reach a real cutout preview or a visible extraction failure.")
            XCTAssertEqual(app.state, .runningForeground)
        }
        waitForProcessingResult()
        let review = app.segmentedControls["import.preview"]
        if review.exists {
            capture(app, "Real pasted garment reaches cutout review")
            review.buttons["Original"].tap(); review.buttons["Cutout"].tap()
            XCTAssertTrue(app.navigationBars.buttons["Save"].exists)
            app.navigationBars.buttons["Cancel"].tap()
            app.buttons["toast.confirm"].tap()
        } else {
            XCTAssertTrue(app.buttons["Retry selected image"].exists,
                "An extraction failure must retain the actual selected image for retry.")
            capture(app, "Actual extraction failure leaves processing and retains the image")
            app.buttons["toast.dismiss"].tap()
            app.buttons["Retry selected image"].tap()
            waitForProcessingResult()
            capture(app, "Retry completes without canceling itself on the view transition")
            if app.segmentedControls["import.preview"].exists {
                app.navigationBars.buttons["Cancel"].tap(); app.buttons["toast.confirm"].tap()
            } else {
                app.buttons["toast.dismiss"].tap(); app.navigationBars.buttons["Cancel"].tap()
            }
        }
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testImportInputsAreAvailableAndCancelReturnsToWardrobe() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        app.navigationBars.buttons["Import garment image"].tap()
        XCTAssertTrue(app.buttons["Choose from Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose a file"].exists)
        XCTAssertTrue(app.buttons["Paste image"].exists)
        for title in ["Choose from Library", "Choose a file", "Paste image"] {
            let button = app.buttons[title]
            XCTAssertTrue(button.staticTexts[title].exists)
            XCTAssertGreaterThan(button.frame.width, 240)
            XCTAssertGreaterThanOrEqual(button.frame.height, 56)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Native import choices"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testEmptyOutfitCannotSaveAndDiscardRemovesNameDraft() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        let name = app.textFields["outfit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        XCTAssertTrue(app.buttons["outfit.add"].exists)
        name.tap()
        name.typeText(" · unsaved draft")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["toast.confirm"].waitForExistence(timeout: 5))
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 5))
        app.buttons["journal.create"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "New outfit")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Native empty flatlay editor"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testGarmentPickerCanCancelWithoutCreatingALayer() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        XCTAssertTrue(app.buttons["outfit.add"].waitForExistence(timeout: 5))
        app.buttons["outfit.add"].tap()
        app.buttons["outfit.addGarment"].tap()
        XCTAssertTrue(app.navigationBars["Add Garment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons["Import"].exists)
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.textFields["outfit.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testShoppingHasItsOwnImportAndOutfitSelectionEntry() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Shopping"].tap()
        app.buttons["shopping.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Shopping Item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose from Library"].exists)
        XCTAssertFalse(app.pickers["Status"].exists)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        XCTAssertTrue(app.buttons["outfit.add"].waitForExistence(timeout: 5))
        app.buttons["outfit.add"].tap()
        app.buttons["outfit.tryShoppingItem"].tap()
        XCTAssertTrue(app.navigationBars["Try Shopping Item"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testJournalHasTwoCollectionsAndCharacterIsAvailableInsideEditor() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Journal"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Outfits"].exists)
        XCTAssertFalse(app.tabBars.buttons["Outfits"].exists)
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        app.buttons["Character"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].isEnabled)
        XCTAssertFalse(app.navigationBars["My character"].exists)
        app.buttons["Layers"].tap()
        XCTAssertTrue(app.buttons["Your character"].waitForExistence(timeout: 5))
        app.navigationBars["Layers"].buttons["Done"].tap()
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Outfits"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testCharacterIsPrimaryAndResponsiveWhilePreviewsLoad() {
        let app = XCUIApplication()
        for largestText in [false, true] {
            app.launchArguments = largestText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
            app.launch()
            let entry = app.buttons["wardrobe.character"]
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            XCTAssertTrue(entry.isHittable)
            capture(app, largestText ? "Primary character entry at largest text" : "Primary character entry")
            openCharacter(app)
            XCTAssertFalse(app.navigationBars["Settings"].exists)
            app.buttons["character.tab.Hair"].tap()
            let face = app.buttons["character.tab.Face"]
            for _ in 0..<5 where !face.isHittable { app.scrollViews["character.tabs"].swipeLeft() }
            XCTAssertTrue(face.isHittable)
            face.tap()
            app.buttons["character.face.Eyes"].tap()
            XCTAssertTrue(app.buttons["Eyes, Round"].waitForExistence(timeout: 5))
            capture(app, largestText ? "Responsive character editor at largest text" : "Responsive character editor")
            app.navigationBars.buttons["Cancel"].tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            XCTAssertTrue(entry.isHittable)
            openCharacter(app)
            app.navigationBars.buttons["Save"].tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            app.buttons["wardrobe.settings"].tap()
            XCTAssertTrue(app.buttons["preferences.currency"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["settings.character"].exists)
            XCTAssertFalse(app.navigationBars["Settings"].buttons["My character"].exists)
            app.navigationBars["Settings"].buttons["Cancel"].tap()
            app.terminate()
        }
    }

    func testCharacterSettingsHaveIndependentPartsAndDiscard() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        openCharacter(app)
        XCTAssertTrue(app.navigationBars["My character"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Female"].exists)
        XCTAssertFalse(app.buttons["Male"].exists)
        func open(_ title: String) {
            let button = app.buttons["character.tab.\(title)"]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.exists)
        }
        func reveal(_ name: String) -> XCUIElement {
            let button = app.buttons[name]
            for _ in 0..<7 where !button.exists || !button.isHittable { app.scrollViews["character.options"].swipeUp() }
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            return button
        }
        open("Body")
        app.buttons["Silhouette, Straight"].tap()
        open("Arms")
        let originalLongArms = app.buttons["Arm length, Long"].isSelected
        app.buttons["Arm length, Long"].tap()
        reveal("Arm build, Muscular").tap()
        capture(app, "Native independent arm proportions")
        open("Legs")
        app.buttons["Leg length, Short"].tap()
        reveal("Leg build, Athletic").tap()
        open("Arms")
        XCTAssertTrue(app.buttons["Arm length, Long"].isSelected)
        XCTAssertTrue(reveal("Arm build, Muscular").isSelected)
        open("Hair")
        app.buttons["Long"].tap()
        let longHair = reveal("Hairstyle, Long")
        let originalLongHair = longHair.isSelected
        if originalLongHair { reveal("Hairstyle, Wavy").tap() } else { longHair.tap() }
        capture(app, "Native shared long and short hairstyles")
        open("Face")
        XCTAssertTrue(app.buttons["Face shape, Square"].exists)
        XCTAssertTrue(app.buttons["Face shape, Square"].staticTexts["Square"].exists)
        capture(app, "Native graphic face choices")
        open("Beard")
        reveal("Beard, Full beard").tap()
        XCTAssertTrue(app.buttons["Beard, Full beard"].isSelected)
        XCTAssertTrue(app.buttons["Beard, Full beard"].staticTexts["Full beard"].exists)
        capture(app, "Native graphic beard choices")
        open("Face")
        app.buttons["character.face.Eyes"].tap()
        reveal("Eye size, Large").tap()
        XCTAssertTrue(app.buttons["Eye size, Large"].isSelected)
        XCTAssertFalse(app.buttons["character.tab.Accessories"].exists)
        capture(app, "Native independent eye size")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["toast.confirm"].waitForExistence(timeout: 5))
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        openCharacter(app)
        open("Hair")
        app.buttons["Long"].tap()
        XCTAssertEqual(reveal("Hairstyle, Long").isSelected, originalLongHair)
        open("Arms")
        XCTAssertEqual(app.buttons["Arm length, Long"].isSelected, originalLongArms)
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testSynchronizedHairGroupsSaveAndReopen() {
        let app = XCUIApplication(); app.launch()
        openCharacter(app)
        XCTAssertTrue(app.buttons["character.tab.Hair"].waitForExistence(timeout: 15))
        app.buttons["character.tab.Hair"].tap()
        func reveal(_ name: String) -> XCUIElement {
            let button = app.buttons[name]
            for _ in 0..<8 where !button.exists || !button.isHittable { app.scrollViews["character.options"].swipeUp() }
            XCTAssertTrue(button.waitForExistence(timeout: 10)); return button
        }
        func selectGroup(_ title: String) {
            let button = app.segmentedControls.buttons[title]
            for _ in 0..<8 where !button.isHittable { app.scrollViews["character.options"].swipeDown() }
            XCTAssertTrue(button.isHittable); button.tap()
        }
        XCTAssertFalse(app.segmentedControls.buttons["New"].exists)
        XCTAssertEqual(app.segmentedControls.buttons.count, 3)
        selectGroup("Short")
        reveal("Hairstyle, Textured Crop").tap()
        capture(app, "Synchronized native short hair and exposed ears")
        selectGroup("Medium")
        reveal("Hairstyle, Medium Curls").tap()
        selectGroup("Long")
        reveal("Hairstyle, Low Man Bun").tap()
        capture(app, "Synchronized native length groups")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["My character"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch(); openCharacter(app)
        XCTAssertTrue(app.buttons["character.tab.Hair"].waitForExistence(timeout: 15))
        app.buttons["character.tab.Hair"].tap()
        XCTAssertFalse(app.segmentedControls.buttons["New"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Long"].isSelected)
        XCTAssertTrue(reveal("Hairstyle, Low Man Bun").isSelected)
        app.navigationBars.buttons["Cancel"].tap(); app.terminate()
    }

    func testCharacterFeaturesRemainReachableAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openCharacter(app)
        let face = app.buttons["character.tab.Face"]
        for _ in 0..<5 where !face.isHittable { app.scrollViews["character.tabs"].swipeLeft() }
        XCTAssertTrue(face.isHittable)
        face.tap()
        app.scrollViews["character.face-tabs"].swipeLeft()
        let mouth = app.buttons["character.face.Mouth"]
        XCTAssertTrue(mouth.isHittable)
        mouth.tap()
        let thin = app.buttons["Mouth fullness, Thin"]
        for _ in 0..<10 where !thin.exists || !thin.isHittable { app.scrollViews["character.options"].swipeUp() }
        XCTAssertTrue(thin.isHittable)
        thin.tap()
        XCTAssertTrue(thin.isSelected)
        capture(app, "Character mouth choices at largest text size")
        app.navigationBars.buttons["Cancel"].tap()
        if app.buttons["toast.confirm"].waitForExistence(timeout: 3) { app.buttons["toast.confirm"].tap() }
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testFilterPanelCanCancelAndApplyWithoutLeavingWardrobe() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["wardrobe.filters"].tap()
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons["Apply"].exists)
        XCTAssertFalse(app.switches["Black"].exists)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.buttons["wardrobe.filters"].tap()
        app.buttons["Clear filters"].tap()
        app.navigationBars.buttons["Apply"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate()
    }
}

extension NavigationTests {
    func testSavedCharacterOutfitAndDiaryCopiesReopenIndependently() {
        let app = XCUIApplication(); app.launch()
        let suffix = UUID().uuidString.prefix(6), outfitName = "Outfit \(suffix)", diaryName = "Wearing \(suffix)"
        openCharacter(app)
        app.navigationBars.buttons["Save"].tap()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        replaceText(app.textFields["outfit.name"], with: outfitName)
        app.buttons["Character"].tap()
        adjustSelectedLayer(app, rotation: 0.6)
        app.buttons["outfit.add"].tap()
        app.buttons["outfit.addGarment"].tap()
        app.buttons.containing(.staticText, identifier: "Inline review tee").firstMatch.tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["View outfit: \(outfitName)"].waitForExistence(timeout: 10))
        app.segmentedControls.buttons["Journal"].tap()
        app.buttons["journal.create"].tap()
        app.buttons["Saved outfit"].tap()
        app.buttons[outfitName].tap()
        replaceText(app.textFields["journal.name"], with: diaryName)
        app.textFields["journal.name"].typeText("\n")
        let note = app.textViews["diary.note"]
        for _ in 0..<8 where !note.isHittable { app.swipeUp() }
        replaceText(note, with: "Independent record")
        app.navigationBars.buttons["Save"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["View outfit: \(outfitName)"].tap()
        XCTAssertTrue(app.buttons["outfit.preview.edit"].waitForExistence(timeout: 5))
        app.buttons["outfit.preview.edit"].tap()
        app.buttons["Character"].tap()
        app.navigationBars.buttons["Save"].tap()
        app.navigationBars["Outfit preview"].buttons["Close"].tap()
        app.terminate(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        let record = app.buttons["View diary entry: \(diaryName)"]
        XCTAssertTrue(record.waitForExistence(timeout: 10)); record.tap()
        XCTAssertTrue(app.staticTexts["Independent record"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Layers"].exists)
        capture(app, "Reopened journal record remains independent of its edited outfit")
        app.navigationBars["Journal entry"].buttons["Close"].tap()
        deleteJournalRow(app, button: "View diary entry: \(diaryName)", confirmation: "Delete entry")
        app.segmentedControls.buttons["Outfits"].tap()
        deleteJournalRow(app, button: "View outfit: \(outfitName)", confirmation: "Delete outfit")
        app.terminate()
    }

    func testShareCancellationAllowsAnotherExportAfterCanvasChange() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        app.buttons["Character"].tap()
        app.buttons["Share image"].tap()
        let close = app.buttons["header.closeButton"]
        let appeared = close.waitForExistence(timeout: 10)
        capture(app, "Native PNG share sheet")
        if !appeared {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Share interface accessibility tree"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(appeared)
        close.tap()
        XCTAssertTrue(app.buttons["Share image"].waitForExistence(timeout: 5))
        adjustSelectedLayer(app, rotation: 0.7)
        app.buttons["Share image"].tap()
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        capture(app, "Second PNG export after changing canvas")
        close.tap()
        XCTAssertTrue(app.buttons["Share image"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        app.terminate()
    }

    func testOutfitPNGSaveToPhotosAndEditedReexport() {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.resetAuthorizationStatus(for: .photos)
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        app.buttons["Character"].tap()
        adjustSelectedLayer(app, rotation: 0.7)

        func saveToPhotos(_ name: String, expectsAuthorization: Bool) {
            app.buttons["Share image"].tap()
            XCTAssertTrue(app.buttons["header.closeButton"].waitForExistence(timeout: 10))
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "\(name) share actions"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let save = app.descendants(matching: .any).matching(NSPredicate(
                format: "identifier == %@ OR label == %@",
                "com.apple.UIKit.activity.SaveToCameraRoll", "Save Image")).firstMatch
            guard save.waitForExistence(timeout: 5) else {
                XCTFail("The system share sheet must offer saving this PNG to Photos.")
                return
            }
            save.tap()
            let alert = springboard.alerts.firstMatch
            if expectsAuthorization {
                XCTAssertTrue(alert.waitForExistence(timeout: 5))
                XCTAssertEqual(alert.buttons.count, 2)
                // The observed add-only alert places Allow after Deny.
                let allow = alert.buttons.element(boundBy: 1)
                capture(springboard, "Photo additions authorization")
                allow.tap()
            }
            XCTAssertTrue(app.buttons["Share image"].waitForExistence(timeout: 10))
            capture(app, name)
        }

        saveToPhotos("Editor after saving default white portrait PNG", expectsAuthorization: true)
        adjustSelectedLayer(app, rotation: 0.4)
        saveToPhotos("Editor after saving rotated white portrait PNG", expectsAuthorization: false)
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testDeniedPhotoAdditionKeepsDraftAndAllowsAnotherShare() {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.resetAuthorizationStatus(for: .photos)
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        replaceText(app.textFields["outfit.name"], with: "Permission check draft")
        app.buttons["Character"].tap()
        adjustSelectedLayer(app, rotation: 0.7)
        app.buttons["Share image"].tap()
        XCTAssertTrue(app.buttons["header.closeButton"].waitForExistence(timeout: 10))
        let save = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ OR label == %@",
            "com.apple.UIKit.activity.SaveToCameraRoll", "Save Image")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let authorization = springboard.alerts.firstMatch
        XCTAssertTrue(authorization.waitForExistence(timeout: 5))
        XCTAssertEqual(authorization.buttons.count, 2)
        capture(springboard, "Declining actual photo additions authorization")
        authorization.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(authorization.waitForNonExistence(timeout: 5))
        capture(app, "Actual state after photo-save permission denial")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Photo denial accessibility tree"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        if app.buttons["header.closeButton"].exists { app.buttons["header.closeButton"].tap() }
        XCTAssertTrue(app.buttons["Share image"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Share image"].isHittable)
        XCTAssertEqual(app.textFields["outfit.name"].value as? String, "Permission check draft")
        adjustSelectedLayer(app, rotation: 0.4)
        app.buttons["Share image"].tap()
        XCTAssertTrue(app.buttons["header.closeButton"].waitForExistence(timeout: 10))
        capture(app, "Another share remains available after denial and edits")
        app.buttons["header.closeButton"].tap()
        XCTAssertTrue(app.buttons["Share image"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your saved outfits"].exists)
        app.terminate()
    }

    func testPreferencesSuccessfullySaveAndReopenAfterRelaunch() {
        let app = XCUIApplication(); app.launch()
        openGarmentDefaults(app)
        selectCurrency(app, code: "SEK")
        replaceText(app.textFields["preferences.cost"], with: "7")
        replaceText(app.textFields["preferences.years"], with: "3")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); openGarmentDefaults(app)
        XCTAssertEqual(app.buttons["preferences.currency"].value as? String, "SEK")
        XCTAssertEqual(textValue(app.textFields["preferences.cost"]), "7")
        XCTAssertEqual(textValue(app.textFields["preferences.years"]), "3")
        capture(app, "Selected currency and clear wearing goals survive relaunch")
        selectCurrency(app, code: "")
        replaceText(app.textFields["preferences.cost"], with: "")
        replaceText(app.textFields["preferences.years"], with: "")
        app.navigationBars.buttons["Save"].tap()
        app.terminate(); app.launch(); openGarmentDefaults(app)
        XCTAssertEqual(app.buttons["preferences.currency"].value as? String, "No currency")
        XCTAssertEqual(textValue(app.textFields["preferences.cost"]), "")
        XCTAssertEqual(textValue(app.textFields["preferences.years"]), "")
        capture(app, "Optional settings remain blank after clearing")
        app.navigationBars.buttons["Cancel"].tap(); app.terminate()
    }

    func testBrandTextCreationAndEditingPersistAfterRelaunch() {
        let app = XCUIApplication()
        let name = "UI brand \(UUID().uuidString.prefix(6))"
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Brands"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        app.buttons["brands.add"].tap()
        replaceText(app.textFields["brand.name"], with: name)
        replaceText(app.textFields["brand.website"], with: "https://example.com")
        replaceText(app.descendants(matching: .any).matching(identifier: "brand.notes").firstMatch, with: "Inspect fabric and fit")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Brands"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        let row = app.buttons.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["Inspect fabric and fit"].exists)
        XCTAssertTrue(app.buttons["Open website"].exists)
        app.navigationBars.buttons["Edit"].tap()
        replaceText(app.descendants(matching: .any).matching(identifier: "brand.notes").firstMatch, with: "Check winter knitwear")
        app.navigationBars.buttons["Save"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Brands"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["Check winter knitwear"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Inspect fabric and fit"].exists)
        capture(app, "Brand metadata edited and reopened")
        app.terminate()
    }

    func testLongBrandFormKeepsKeyboardActionsReachableAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        let name = "\(UUID().uuidString.prefix(6)) Clothing and accessories for everyday winter walks"
        let note = "Compare the wool fabric, shoulder fit, and room for a warm sweater.\nCheck how the coat works with the clothes already saved in my wardrobe."
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Brands"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        app.buttons["brands.add"].tap()
        replaceText(app.textFields["brand.name"], with: name)
        let notes = app.descendants(matching: .any).matching(identifier: "brand.notes").firstMatch
        if !notes.isHittable { app.swipeUp() }
        replaceText(notes, with: note)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(app.navigationBars.buttons["Save"].isHittable)
        XCTAssertTrue(app.navigationBars.buttons["Cancel"].isHittable)
        XCTAssertEqual(textValue(notes), note)
        capture(app, "Largest text brand notes with keyboard")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Brands"].tap()
        XCTAssertTrue(app.navigationBars["Brands"].waitForExistence(timeout: 5))
        let row = app.buttons.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        capture(app, "Largest text saved long brand name")
        row.tap()
        XCTAssertTrue(app.navigationBars.buttons["Edit"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Edit"].tap()
        XCTAssertEqual(textValue(app.textFields["brand.name"]), name)
        if !notes.isHittable { app.swipeUp() }
        XCTAssertEqual(textValue(notes), note)
        app.swipeDown()
        replaceText(app.textFields["brand.name"], with: "Unsaved name")
        XCTAssertTrue(app.navigationBars.buttons["Cancel"].isHittable)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["toast.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["toast.confirm"].isHittable)
        capture(app, "Largest text discard confirmation with keyboard")
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Edit"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Edit"].tap()
        XCTAssertEqual(textValue(app.textFields["brand.name"]), name)
        if !notes.isHittable { app.swipeUp() }
        XCTAssertEqual(textValue(notes), note)
        app.navigationBars.buttons["Cancel"].tap()
        app.terminate()
    }

    func testJournalNotesSaveReopenAndDiscardAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.buttons["journal.create"].tap()
        let name = "Large record \(UUID().uuidString.prefix(6))"
        let field = app.textFields["journal.name"]
        replaceText(field, with: name); field.typeText("\n")
        app.buttons["journal.add-pieces"].tap()
        let piece = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "journal.piece.", "Inline review tee")).firstMatch
        for _ in 0..<8 where !piece.isHittable { app.swipeUp() }
        piece.tap()
        app.navigationBars["Choose pieces"].buttons["Done"].tap()
        let notes = app.textViews["diary.note"]
        for _ in 0..<8 where !notes.isHittable { app.swipeUp() }
        replaceText(notes, with: "Saved wearing notes\nComfortable throughout the day")
        capture(app, "Largest text journal record and keyboard")
        XCTAssertTrue(app.navigationBars.buttons["Save"].isHittable)
        XCTAssertFalse(app.buttons["Share image"].exists)
        app.navigationBars.buttons["Save"].tap()
        app.terminate(); app.launch(); app.tabBars.buttons["Journal"].tap()
        let row = app.buttons["View diary entry: \(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        app.buttons["journal.preview.edit"].tap()
        for _ in 0..<8 where !notes.isHittable { app.swipeUp() }
        XCTAssertEqual(textValue(notes), "Saved wearing notes\nComfortable throughout the day")
        replaceText(notes, with: "Unsaved")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["toast.cancel"].waitForExistence(timeout: 5))
        capture(app, "Largest text centered discard card")
        app.buttons["toast.confirm"].tap()
        app.navigationBars["Journal entry"].buttons["Close"].tap()
        deleteJournalRow(app, button: "View diary entry: \(name)", confirmation: "Delete entry")
        app.terminate()
    }

    private func selectedLayerCenter(_ app: XCUIApplication) -> XCUICoordinate {
        let top = app.descendants(matching: .any).matching(identifier: "layer.resize.top").firstMatch.frame
        let bottom = app.descendants(matching: .any).matching(identifier: "layer.resize.bottom").firstMatch.frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: top.midX, dy: (top.midY + bottom.midY) / 2))
    }

    private func textValue(_ field: XCUIElement) -> String {
        let value = field.value as? String ?? ""
        return value == field.placeholderValue ? "" : value
    }

    private func adjustSelectedLayer(_ app: XCUIApplication, rotation: Double) {
        app.buttons["Layers"].tap()
        let slider = app.sliders["Layer rotation"]
        for _ in 0..<8 where !slider.isHittable { app.swipeUp() }
        XCTAssertTrue(slider.isHittable)
        slider.adjust(toNormalizedSliderPosition: rotation)
        app.navigationBars["Layers"].buttons["Done"].tap()
    }

    private func openCharacter(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["wardrobe.character"].waitForExistence(timeout: 5))
        app.buttons["wardrobe.character"].tap()
        XCTAssertTrue(app.navigationBars["My character"].waitForExistence(timeout: 15))
    }

    private func selectCurrency(_ app: XCUIApplication, code: String) {
        app.buttons["preferences.currency"].tap()
        if code.isEmpty {
            app.buttons["preferences.currency.none"].tap()
        } else {
            replaceText(app.textFields["preferences.currency.search"], with: code)
            let option = app.buttons["preferences.currency.option.\(code)"]
            XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
        }
        XCTAssertFalse(app.textFields["preferences.currency.search"].exists)
    }

    private func openGarmentDefaults(_ app: XCUIApplication) {
        app.buttons["wardrobe.settings"].tap()
        XCTAssertTrue(app.buttons["preferences.currency"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.defaults"].exists)
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let existing = textValue(field)
        field.tap()
        if !existing.isEmpty {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        if !text.isEmpty { field.typeText(text) }
    }

    private func deleteJournalRow(_ app: XCUIApplication, button: String, confirmation: String) {
        let name = button.components(separatedBy: ": ").dropFirst().joined(separator: ": ")
        let kind = confirmation == "Delete outfit" ? "Outfit" : "Diary"
        let menu = app.buttons["\(kind) actions: \(name)"]
        for _ in 0..<12 where !menu.exists { app.swipeUp() }
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons[confirmation].tap()
        app.buttons["toast.confirm"].tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}


extension NavigationTests {
    func testBrandFilterAndShoppingWebsiteQuotePersist() {
        let app = XCUIApplication(); app.launch()
        app.buttons["wardrobe.filters"].tap()
        let brand = app.descendants(matching: .any).matching(identifier: "filter.brand").firstMatch
        XCTAssertTrue(brand.waitForExistence(timeout: 5))
        brand.tap()
        app.buttons["Review brand"].tap()
        capture(app, "Wardrobe brand filter")
        app.navigationBars.buttons["Apply"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Inline review tee").firstMatch.waitForExistence(timeout: 5))
        app.buttons["wardrobe.filters"].tap()
        app.buttons["Clear filters"].tap()
        app.navigationBars.buttons["Apply"].tap()
        app.tabBars.buttons["Shopping"].tap()
        app.buttons.containing(.staticText, identifier: "Inline shopping review").firstMatch.tap()
        let add = app.buttons["shopping.add-website"]
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        add.tap()
        replaceText(app.textFields["offer.retailer"], with: "Review retailer")
        replaceText(app.textFields["offer.website"], with: "https://example.com/product")
        replaceText(app.textFields["offer.price"], with: "120.50")
        XCTAssertFalse(app.textFields["offer.currency"].exists)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Review retailer"].waitForExistence(timeout: 5))
        capture(app, "Shopping website and quoted price")
        app.terminate(); app.launch(); app.tabBars.buttons["Shopping"].tap()
        app.buttons.containing(.staticText, identifier: "Inline shopping review").firstMatch.tap()
        for _ in 0..<5 where !app.staticTexts["Review retailer"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Review retailer"].exists)
        app.buttons["Delete website: Review retailer"].tap()
        XCTAssertFalse(app.staticTexts["Review retailer"].exists)
        app.terminate()
    }
}

extension NavigationTests {
    private func nativeTextAction(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ AND (elementType == %d OR elementType == %d)", title,
            XCUIElement.ElementType.menuItem.rawValue, XCUIElement.ElementType.button.rawValue)).firstMatch
    }

    func testNativeTextEditingMenuWithKeyboardVisible() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Brands"].tap()
        app.buttons["brands.add"].tap()
        let name = app.textFields["brand.name"]
        name.tap(); name.typeText("Wardrobe sample")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        name.doubleTap()
        let copy = nativeTextAction(app, "Copy")
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "The native text edit menu must remain available while the keyboard is visible.")
        capture(app, "Native Copy menu with keyboard visible")
        copy.tap()
        let website = app.textFields["brand.website"]
        website.tap(); website.press(forDuration: 1)
        let paste = nativeTextAction(app, "Paste")
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        XCTAssertFalse(textValue(website).isEmpty)
        website.doubleTap()
        XCTAssertTrue(nativeTextAction(app, "Cut").waitForExistence(timeout: 5))
        capture(app, "Native Cut and Paste remain available after switching fields")
        nativeTextAction(app, "Cut").tap()
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        name.tap(); name.doubleTap()
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        capture(app, "Native edit menu after reopening keyboard")
        app.terminate()
    }

    func testNativeNotesSelectionAndKeyboardDismissal() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Journal"].tap()
        app.buttons["journal.create"].tap()
        let note = app.textViews["diary.note"]
        for _ in 0..<5 where !note.isHittable { app.swipeUp() }
        note.tap(); note.typeText("Blue coat.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(note), "Blue coat.")
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.1)).doubleTap()
        XCTAssertTrue(nativeTextAction(app, "Copy").waitForExistence(timeout: 5))
        capture(app, "Native text editor menu while keyboard is visible")
        nativeTextAction(app, "Cut").tap()
        XCTAssertNotEqual(textValue(note), "Blue coat.")
        XCTAssertEqual(app.buttons.matching(identifier: "keyboard.done").count, 1)
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        note.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "keyboard.done").count, 1)
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.terminate()
    }

    func testCollectionImageTilesAlignDespiteDifferentMetadataHeights() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Wardrobe"].tap()
        let images = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@ AND label ENDSWITH %@", "garment.card.image.", "Grid review", " image"))
        XCTAssertTrue(images.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(images.count, 2)
        let first = images.element(boundBy: 0).frame, second = images.element(boundBy: 1).frame
        XCTAssertEqual(first.minY, second.minY, accuracy: 1)
        XCTAssertEqual(first.width, first.height, accuracy: 1)
        XCTAssertEqual(second.width, second.height, accuracy: 1)
        capture(app, "Borderless square garment tiles align at the top")
        app.terminate()
    }

    func testCurrencyOptionsAreCurrentCodesWithoutSecondaryCopy() {
        let app = XCUIApplication(); app.launch()
        openGarmentDefaults(app)
        XCTAssertFalse(app.staticTexts["Your goal for what each wear should cost."].exists)
        XCTAssertFalse(app.staticTexts["How many years you want to wear each new piece."].exists)
        app.buttons["preferences.currency"].tap()
        let search = app.textFields["preferences.currency.search"]
        search.tap(); search.typeText("dollar")
        XCTAssertFalse(app.buttons["preferences.currency.option.USN"].exists)
        XCTAssertFalse(app.buttons["preferences.currency.option.USS"].exists)
        replaceText(search, with: "USD")
        let usd = app.buttons["preferences.currency.option.USD"]
        XCTAssertTrue(usd.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["US Dollar"].exists)
        capture(app, "Currency search shows current single-line codes")
        usd.tap()
        XCTAssertEqual(app.buttons["preferences.currency"].value as? String, "USD")
        XCTAssertFalse(app.staticTexts["US Dollar"].exists)
        capture(app, "Settings without explanatory footnotes")
        app.navigationBars.buttons["Cancel"].tap()
        if app.buttons["toast.confirm"].waitForExistence(timeout: 2) { app.buttons["toast.confirm"].tap() }
        app.terminate()
    }

    func testSettingsInputsAndKeyboardDismissalAreDirect() {
        let app = XCUIApplication(); app.launch()
        openGarmentDefaults(app)
        XCTAssertFalse(app.buttons["settings.defaults"].exists)
        let code = app.buttons["preferences.currency"]
        selectCurrency(app, code: "")
        let cost = app.textFields["preferences.cost"]
        replaceText(cost, with: "4")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5))
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        code.tap()
        XCTAssertTrue(app.textFields["preferences.currency.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        code.tap()
        capture(app, "Settings inputs shown directly")
        app.navigationBars["Settings"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("review\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Journal"].tap(); app.buttons["journal.create"].tap()
        let note = app.textViews["diary.note"]
        for _ in 0..<5 where !note.isHittable { app.swipeUp() }
        XCTAssertTrue(note.exists); note.tap(); note.typeText("Keyboard review")
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5)); app.buttons["keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap(); app.buttons["toast.confirm"].tap()
        app.terminate()
    }

    func testBrandEditingStaysInPlaceAndAcceptsBareWebsite() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Brands"].tap()
        app.buttons["brands.add"].tap()
        let reviewName = "Interaction review " + UUID().uuidString.prefix(6)
        replaceText(app.textFields["brand.name"], with: reviewName)
        replaceText(app.textFields["brand.website"], with: "www.example.com")
        app.navigationBars.buttons["Save"].tap()
        let row = app.buttons["brands.profile." + reviewName.lowercased()]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.navigationBars.buttons["Edit"].tap()
        let sizing = app.textFields["brand.sizing"]
        XCTAssertTrue(sizing.waitForExistence(timeout: 5))
        replaceText(sizing, with: "M, relaxed")
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5))
        app.buttons["keyboard.done"].tap()
        capture(app, "Brand editing in the existing page")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Size, M, relaxed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["Open website"].exists || app.buttons["Open website"].exists)
        XCTAssertFalse(app.textFields["brand.name"].exists)
        app.navigationBars.buttons["Edit"].tap()
        replaceText(app.textFields["brand.sizing"], with: "Do not retain")
        app.buttons["keyboard.done"].tap()
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["toast.confirm"].tap()
        XCTAssertTrue(app.staticTexts["Size, M, relaxed"].exists)
        app.buttons["brand.delete"].tap(); app.buttons["toast.confirm"].tap()
        app.terminate()
    }

    func testShoppingHasDirectActionsWithoutStyleOrCurrencyInputs() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Shopping"].tap()
        let item = app.buttons.containing(.staticText, identifier: "Inline shopping review").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.buttons["shopping.acquire"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shopping.estimate"].exists)
        XCTAssertTrue(app.buttons["Remove shopping item"].exists)
        XCTAssertFalse(app.buttons["shopping.style"].exists)
        app.buttons["shopping.estimate"].tap()
        XCTAssertTrue(app.textFields["purchase.price"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["purchase.currency"].exists)
        XCTAssertFalse(app.buttons["Style with your wardrobe"].exists)
        replaceText(app.textFields["purchase.price"], with: "120")
        app.buttons["keyboard.done"].tap()
        capture(app, "Calculator without a currency field or Style action")
        app.navigationBars.buttons["Close"].tap()
        app.buttons["shopping.add-website"].tap()
        let retailer = "Bare address " + UUID().uuidString.prefix(6)
        replaceText(app.textFields["offer.retailer"], with: retailer)
        replaceText(app.textFields["offer.website"], with: "www.example.com/item")
        replaceText(app.textFields["offer.price"], with: "90")
        XCTAssertFalse(app.textFields["offer.currency"].exists)
        app.buttons["keyboard.done"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[retailer].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["90"].exists)
        capture(app, "Direct shopping actions and website quote")
        app.buttons["Delete website: " + retailer].tap()
        XCTAssertFalse(app.staticTexts[retailer].exists)
        app.terminate()
    }
}

extension NavigationTests {
    func testCanvasPinchChangesOnlyTheSelectedSticker() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        app.buttons["journal.create"].tap()
        app.buttons["Character"].tap(); app.buttons["Character"].tap()
        let layers = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "outfit.layer.", ", layer "))
        XCTAssertEqual(layers.count, 2)
        let other = layers.element(boundBy: 0), selected = layers.element(boundBy: 1)
        let before = selected.value as? String, untouched = other.value as? String
        selected.pinch(withScale: 1.35, velocity: 1)
        XCTAssertNotEqual(selected.value as? String, before)
        XCTAssertEqual(other.value as? String, untouched)
        capture(app, "Pinch affects only the selected sticker")
        app.buttons["outfit.undo"].tap()
        XCTAssertEqual(selected.value as? String, before)
        app.navigationBars.buttons["Cancel"].tap(); app.buttons["toast.confirm"].tap()
        app.terminate()
    }
}
