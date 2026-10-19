import SwiftUI
import SwiftData
import Charts

// MARK: - Libreria

struct LibreriaView: View {
    @Query(sort: \Articolo.creato, order: .reverse) private var articoli: [Articolo]
    @State private var nuovo = false
    @State private var daVendere: Articolo? = nil

    private var inLibreria: [Articolo] { articoli.filter { !$0.venduto } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Voce(titolo: "Articoli", valore: "\(inLibreria.count)")
                        Voce(titolo: "Hai speso", valore: eur(articoli.reduce(0) { $0 + $1.costo }))
                        Voce(titolo: "Venduti", valore: "\(articoli.count - inLibreria.count)")
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))

                    if inLibreria.isEmpty {
                        ContentUnavailableView("Libreria vuota", systemImage: "books.vertical",
                                               description: Text("Tocca + per caricare un articolo e quanto l'hai pagato."))
                    } else {
                        Riquadro {
                            ForEach(inLibreria) { a in
                                HStack {
                                    NavigationLink(value: a) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(a.nome).bold().foregroundStyle(Color.primary)
                                            Text("pagato \(eur(a.costo)) · \(a.creato.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT"))))")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    Button("Venduto") { daVendere = a }
                                        .font(.caption.bold()).foregroundStyle(.white)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.orange, in: Capsule())
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("venduto-\(a.nome)")
                                }
                                .padding(.vertical, 8)
                                if a.id != inLibreria.last?.id { Divider() }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.sfondo)
            .navigationTitle("Libreria")
            .navigationDestination(for: Articolo.self) { DettaglioView(articolo: $0) }
            .toolbar {
                Button { nuovo = true } label: { Image(systemName: "plus") }.accessibilityIdentifier("nuovoArticolo")
            }
            .sheet(isPresented: $nuovo) { ArticoloForm(statoIniziale: .inVendita) }
            .sheet(item: $daVendere) { ArticoloForm(articolo: $0, vendi: true) }
        }
    }
}

// MARK: - Ricerca su tutti gli articoli

struct RicercaView: View {
    @Query(sort: \Articolo.creato, order: .reverse) private var articoli: [Articolo]
    @Environment(\.dismiss) private var dismiss
    @State private var testo = ""
    @State private var filtro = 0

    private var risultati: [Articolo] { Calcoli.cerca(articoli, testo: testo, filtro: filtro) }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filtro", selection: $filtro) {
                    Text("Tutti").tag(0)
                    Text("Libreria").tag(1)
                    Text("Venduti").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                Section("\(risultati.count) risultati") {
                    ForEach(risultati) { a in
                        NavigationLink(value: a) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.nome).bold()
                                    Text(a.venduto ? "pagato \(eur(a.costo)) · venduto \(eur(a.prezzo))" : "pagato \(eur(a.costo))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(a.venduto ? a.stato.nomeSingolo : "In libreria")
                                    .font(.caption.bold()).foregroundStyle(a.stato.colore)
                            }
                        }
                    }
                }
            }
            .searchable(text: $testo, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca per nome")
            .navigationTitle("Cerca")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Articolo.self) { DettaglioView(articolo: $0) }
            .toolbar { Button("Chiudi") { dismiss() } }
        }
    }
}

// MARK: - Statistiche

struct StatisticheView: View {
    @Query private var articoli: [Articolo]

    var body: some View {
        let mesi = Calcoli.ultimiMesi(articoli)
        let venduti = articoli.filter(\.venduto)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Riquadro {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Guadagno ultimi 6 mesi").font(.caption).foregroundStyle(.secondary)
                            Text(eur(mesi.reduce(0) { $0 + $1.valore })).font(.title.bold())
                            Chart(Array(mesi.enumerated()), id: \.offset) { e in
                                BarMark(x: .value("Mese", e.element.mese.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "it_IT")))),
                                        y: .value("Guadagno", e.element.valore))
                                    .foregroundStyle(e.offset == mesi.count - 1 ? Color.inchiostro : Color.gray.opacity(0.35))
                                    .cornerRadius(6)
                            }
                            .frame(height: 160)
                        }
                        .padding(.vertical, 8)
                    }
                    Text("DOVE SONO GLI ORDINI").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                    Riquadro {
                        ForEach([Stato.inVendita, .daSpedire, .spedito, .pagato]) { s in
                            Riga("● \(s.nome)", "\(articoli.filter { $0.stato == s }.count)", colore: s.colore)
                        }
                        if let t = Calcoli.tempoMedioSpedizione(articoli) {
                            Riga("Tempo medio di spedizione", t.formatted(.number.precision(.fractionLength(1))) + " giorni")
                        }
                    }
                    HStack(spacing: 10) {
                        Riquadro { Riga("Vendite", "\(venduti.count)") }
                        Riquadro { Riga("Media", eur(venduti.isEmpty ? 0 : venduti.reduce(0) { $0 + $1.prezzo } / Double(venduti.count))) }
                    }
                    Text("PER SITO").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                    Riquadro {
                        let siti = Dictionary(grouping: venduti, by: \.sito)
                        if siti.isEmpty { Riga("Nessuna vendita", "") }
                        ForEach(siti.keys.sorted(), id: \.self) { s in
                            Riga(s, eur(siti[s]!.reduce(0) { $0 + $1.guadagno }))
                        }
                    }
                }
                .padding()
            }
            .background(Color.sfondo)
            .navigationTitle("Statistiche")
        }
    }
}

// MARK: - Altro

struct AltroView: View {
    @Query(sort: \Articolo.creato, order: .reverse) private var articoli: [Articolo]
    @AppStorage("siti") private var siti = "Vinted, Subito, eBay"
    @AppStorage("commissione") private var commissione = 0.0
    @AppStorage("obiettivo") private var obiettivo = 150.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendite") {
                    LabeledContent("Siti dove vendi") {
                        TextField("Vinted, Subito", text: $siti).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Obiettivo del mese (€)") {
                        TextField("150", value: $obiettivo, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Commissioni predefinite (%)") {
                        TextField("0", value: $commissione, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    let fatto = Calcoli.guadagnoMese(articoli, mese: Date())
                    VStack(alignment: .leading) {
                        Text("Obiettivo: \(eur(fatto)) su \(eur(obiettivo))")
                        ProgressView(value: min(max(fatto, 0), max(obiettivo, 1)), total: max(obiettivo, 1)).tint(.green)
                    }
                }
                Section("Dati") {
                    ShareLink(item: FileCSV(testo: Calcoli.csv(articoli)), preview: SharePreview("Vendite.csv")) {
                        Label("Esporta per Excel (CSV)", systemImage: "square.and.arrow.up")
                    }
                }
                Section {
                    Text("Vendite \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                        .frame(maxWidth: .infinity).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Altro")
        }
    }
}

struct FileCSV: Transferable {
    var testo: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { f in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Vendite.csv")
            // Il BOM fa leggere bene a Excel le lettere accentate e il simbolo €.
            try Data(("\u{FEFF}" + f.testo).utf8).write(to: url)
            return SentTransferredFile(url)
        }
    }
}
