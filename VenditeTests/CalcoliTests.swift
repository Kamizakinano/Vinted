import XCTest
@testable import Vendite

final class CalcoliTests: XCTestCase {
    func testGuadagno() {
        let a = Articolo(nome: "Sneakers", prezzo: 42.5, costo: 15, commissioni: 2.9, stato: .daSpedire)
        XCTAssertEqual(a.guadagno, 24.6, accuracy: 0.001)
    }

    func testPassaggiDiStato() {
        let a = Articolo(nome: "Giacca", prezzo: 18)
        XCTAssertFalse(a.venduto)
        a.imposta(.daSpedire)
        XCTAssertNotNil(a.dataVendita)
        XCTAssertNil(a.dataSpedizione)
        a.imposta(.spedito)
        XCTAssertNotNil(a.dataSpedizione)
        a.imposta(.pagato)
        XCTAssertNotNil(a.dataPagamento)
        XCTAssertNil(a.stato.prossimo)
        a.imposta(.inVendita)
        XCTAssertNil(a.dataVendita)
    }

    func testGuadagnoMeseEDaIncassare() {
        let oggi = Date()
        let vecchia = Calendar.current.date(byAdding: .month, value: -2, to: oggi)!
        let lista = [
            Articolo(nome: "A", prezzo: 20, costo: 5, stato: .pagato, data: oggi),
            Articolo(nome: "B", prezzo: 10, commissioni: 1, stato: .spedito, data: oggi),
            Articolo(nome: "C", prezzo: 50, stato: .pagato, data: vecchia),
            Articolo(nome: "D", prezzo: 99, stato: .inVendita, data: oggi),
        ]
        XCTAssertEqual(Calcoli.guadagnoMese(lista, mese: oggi), 24, accuracy: 0.001)
        XCTAssertEqual(Calcoli.daIncassare(lista), 9, accuracy: 0.001)
        let mesi = Calcoli.ultimiMesi(lista, oggi: oggi)
        XCTAssertEqual(mesi.count, 6)
        XCTAssertEqual(mesi.last!.valore, 24, accuracy: 0.001)
        XCTAssertEqual(mesi[3].valore, 50, accuracy: 0.001)
    }

    func testCommissioneECSV() {
        XCTAssertEqual(Calcoli.commissione(prezzo: 42.5, percentuale: 5), 2.13, accuracy: 0.001)
        let csv = Calcoli.csv([Articolo(nome: "Borsa; vintage", prezzo: 25, stato: .pagato)])
        XCTAssertTrue(csv.contains("Borsa, vintage;Vinted;Pagato;"))
        XCTAssertTrue(csv.contains("25,00"))
    }

    func testRicerca() {
        let lista = [
            Articolo(nome: "Giacca jeans", costo: 6, stato: .daSpedire),
            Articolo(nome: "Giacca pelle", costo: 20),
            Articolo(nome: "Stivali", costo: 15),
        ]
        XCTAssertEqual(Calcoli.cerca(lista, testo: "giacca", filtro: 0).count, 2)
        XCTAssertEqual(Calcoli.cerca(lista, testo: "GIACCA", filtro: 1).map(\.nome), ["Giacca pelle"])
        XCTAssertEqual(Calcoli.cerca(lista, testo: "giacca", filtro: 2).map(\.nome), ["Giacca jeans"])
        XCTAssertEqual(Calcoli.cerca(lista, testo: " ", filtro: 0).count, 3)
    }
}
