import SwiftUI
import SwiftData

@main
struct VenditeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Articolo.self)
    }
}

// MARK: - Stato di un articolo

enum Stato: Int, CaseIterable, Identifiable {
    case inVendita = 0, daSpedire, spedito, pagato
    var id: Int { rawValue }

    var nome: String {
        switch self {
        case .inVendita: return "In vendita"
        case .daSpedire: return "Da spedire"
        case .spedito: return "Spediti"
        case .pagato: return "Pagati"
        }
    }
    var nomeSingolo: String {
        switch self {
        case .inVendita: return "In vendita"
        case .daSpedire: return "Da spedire"
        case .spedito: return "Spedito"
        case .pagato: return "Pagato"
        }
    }
    var colore: Color {
        switch self {
        case .inVendita: return .gray
        case .daSpedire: return .orange
        case .spedito: return .blue
        case .pagato: return .green
        }
    }
    /// Il passo successivo (nil se è già pagato).
    var prossimo: Stato? { Stato(rawValue: rawValue + 1) }
    var pulsante: String {
        switch self {
        case .inVendita: return "Segna come venduto"
        case .daSpedire: return "Segna come spedito"
        case .spedito: return "Segna come pagato"
        case .pagato: return ""
        }
    }
}

// MARK: - Modello

@Model
final class Articolo {
    var nome: String = ""
    var emoji: String = "👕"
    var prezzo: Double = 0
    var costo: Double = 0
    var commissioni: Double = 0
    var sito: String = "Vinted"
    var statoRaw: Int = 0
    var creato: Date = Date()
    var dataVendita: Date? = nil
    var dataSpedizione: Date? = nil
    var dataPagamento: Date? = nil
    var codiceSpedizione: String = ""
    @Attribute(.externalStorage) var foto: Data? = nil

    init(nome: String = "", emoji: String = "👕", prezzo: Double = 0, costo: Double = 0,
         commissioni: Double = 0, sito: String = "Vinted", stato: Stato = .inVendita, data: Date = Date()) {
        self.nome = nome
        self.emoji = emoji
        self.prezzo = prezzo
        self.costo = costo
        self.commissioni = commissioni
        self.sito = sito
        self.creato = data
        self.statoRaw = stato.rawValue
        if stato != .inVendita { dataVendita = data }
    }

    var stato: Stato {
        get { Stato(rawValue: statoRaw) ?? .inVendita }
        set { imposta(newValue) }
    }

    var guadagno: Double { prezzo - costo - commissioni }
    var venduto: Bool { stato != .inVendita }

    /// Cambia stato e segna le date dei passaggi.
    func imposta(_ nuovo: Stato, il data: Date = Date()) {
        statoRaw = nuovo.rawValue
        if nuovo == .inVendita { dataVendita = nil; dataSpedizione = nil; dataPagamento = nil; return }
        if dataVendita == nil { dataVendita = data }
        if nuovo.rawValue >= Stato.spedito.rawValue, dataSpedizione == nil { dataSpedizione = data }
        if nuovo == .pagato, dataPagamento == nil { dataPagamento = data }
        if nuovo.rawValue < Stato.pagato.rawValue { dataPagamento = nil }
        if nuovo.rawValue < Stato.spedito.rawValue { dataSpedizione = nil }
    }
}

// MARK: - Calcoli

enum Calcoli {
    static func stessoMese(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, equalTo: b, toGranularity: .month)
    }

    /// Guadagno delle vendite fatte nel mese della data indicata.
    static func guadagnoMese(_ articoli: [Articolo], mese: Date) -> Double {
        articoli.filter { $0.venduto && stessoMese($0.dataVendita ?? $0.creato, mese) }
            .reduce(0) { $0 + $1.guadagno }
    }

    /// Soldi delle vendite non ancora pagate.
    static func daIncassare(_ articoli: [Articolo]) -> Double {
        articoli.filter { $0.stato == .daSpedire || $0.stato == .spedito }
            .reduce(0) { $0 + $1.prezzo - $1.commissioni }
    }

    /// Giorni medi tra vendita e spedizione.
    static func tempoMedioSpedizione(_ articoli: [Articolo]) -> Double? {
        let giorni = articoli.compactMap { a -> Double? in
            guard let v = a.dataVendita, let s = a.dataSpedizione else { return nil }
            return s.timeIntervalSince(v) / 86400
        }
        return giorni.isEmpty ? nil : giorni.reduce(0, +) / Double(giorni.count)
    }

    /// Guadagno degli ultimi `n` mesi, dal più vecchio al più recente.
    static func ultimiMesi(_ articoli: [Articolo], n: Int = 6, oggi: Date = Date()) -> [(mese: Date, valore: Double)] {
        let cal = Calendar.current
        let inizio = cal.date(from: cal.dateComponents([.year, .month], from: oggi)) ?? oggi
        return (0..<n).reversed().map { k in
            let m = cal.date(byAdding: .month, value: -k, to: inizio) ?? inizio
            return (m, guadagnoMese(articoli, mese: m))
        }
    }

    /// Ricerca per nome. filtro: 0 tutti, 1 solo libreria (non venduti), 2 solo venduti.
    static func cerca(_ articoli: [Articolo], testo: String, filtro: Int) -> [Articolo] {
        let t = testo.trimmingCharacters(in: .whitespaces)
        return articoli.filter { a in
            (filtro == 0 || (filtro == 1 && !a.venduto) || (filtro == 2 && a.venduto))
                && (t.isEmpty || a.nome.localizedCaseInsensitiveContains(t))
        }
    }

    static func commissione(prezzo: Double, percentuale: Double) -> Double {
        (prezzo * percentuale).rounded() / 100
    }

    /// Testo CSV (separato da punto e virgola, si apre con Excel).
    static func csv(_ articoli: [Articolo]) -> String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"
        func n(_ v: Double) -> String { String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",") }
        var righe = ["Articolo;Sito;Stato;Data vendita;Prezzo;Pagato da te;Commissioni;Guadagno"]
        for a in articoli {
            let nome = a.nome.replacingOccurrences(of: ";", with: ",")
            righe.append("\(nome);\(a.sito);\(a.stato.nomeSingolo);\(a.dataVendita.map { f.string(from: $0) } ?? "");\(n(a.prezzo));\(n(a.costo));\(n(a.commissioni));\(n(a.guadagno))")
        }
        return righe.joined(separator: "\n")
    }
}

func eur(_ v: Double) -> String {
    v.formatted(.currency(code: "EUR").locale(Locale(identifier: "it_IT")))
}

extension Color {
    static let inchiostro = Color(red: 0x1d / 255, green: 0x24 / 255, blue: 0x33 / 255)
    static let sfondo = Color(red: 0xee / 255, green: 0xf0 / 255, blue: 0xf4 / 255)
}
