import XCTest

final class VenditeUITests: XCTestCase {
    func testNuovaVenditaESpedizione() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["nuovaVendita"].tap()
        let nome = app.textFields["campoNome"]
        XCTAssertTrue(nome.waitForExistence(timeout: 5))
        nome.tap()
        nome.typeText("Giacca jeans")
        let prezzo = app.textFields["campoPrezzo"]
        prezzo.tap()
        prezzo.typeText("18")
        app.buttons["salva"].tap()

        let scheda = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Giacca jeans")).firstMatch
        XCTAssertTrue(scheda.waitForExistence(timeout: 5))
        scheda.tap()
        let avanza = app.buttons["avanza"]
        XCTAssertTrue(avanza.waitForExistence(timeout: 5))
        XCTAssertEqual(avanza.label, "Segna come spedito")
        avanza.tap()
        XCTAssertEqual(app.buttons["avanza"].label, "Segna come pagato")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Statistiche"].tap()
        XCTAssertTrue(app.staticTexts["Guadagno ultimi 6 mesi"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Ordini"].tap()
    }

    func testLibreriaVendutoERicerca() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Libreria"].tap()
        app.buttons["nuovoArticolo"].tap()
        let nome = app.textFields["campoNome"]
        XCTAssertTrue(nome.waitForExistence(timeout: 5))
        nome.tap()
        nome.typeText("Stivali")
        let costo = app.textFields["campoCosto"]
        costo.tap()
        costo.typeText("15")
        app.buttons["salva"].tap()

        let venduto = app.buttons["venduto-Stivali"]
        XCTAssertTrue(venduto.waitForExistence(timeout: 5))
        venduto.tap()
        let prezzo = app.textFields["campoPrezzo"]
        XCTAssertTrue(prezzo.waitForExistence(timeout: 5))
        prezzo.tap()
        prezzo.typeText("40")
        app.buttons["salva"].tap()
        XCTAssertTrue(venduto.waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Ordini"].tap()
        app.buttons["cerca"].tap()
        let campo = app.searchFields.firstMatch
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.tap()
        campo.typeText("stiv")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "pagato 15")).firstMatch.waitForExistence(timeout: 5))
    }
}
