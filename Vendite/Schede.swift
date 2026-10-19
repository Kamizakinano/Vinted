import SwiftUI
import SwiftData
import Charts

// MARK: - Articoli

struct ArticoliView: View {
    @Query(sort: \Articolo.creato, order: .reverse) private var articoli: [Articolo]
    @State private var cerca = ""
    @State private var filtro = 0
    @State private var nuovo = false

    private var mostrati: [Articolo] {
        articoli.filter { a in
            (filtro == 0 || (filtro == 1 && !a.venduto) || (filtro == 2 && a.venduto))
                && (cerca.isEmpty || a.nome.localizedCaseInsensitiveContains(cerca))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Picker("Filtro", selection: $filtro) {
                        Text("Tutti \(articoli.count)").tag(0)
                        Text("In vendita \(articoli.filter { !$0.venduto }.count)").tag(1)
                        Text("Venduti \(articoli.filter(\.venduto).count)").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if mostrati.isEmpty {
                        ContentUnavailableView("Nessun articolo", systemImage: "tshirt",
                                               description: Text("Tocca + per aggiungere quello che hai in vendita."))
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(mostrati) { a in
                            NavigationLink(value: a) { Casella(articolo: a) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color.sfondo)
            .navigationTitle("Articoli")
            .searchable(text: $cerca, prompt: "Cerca tra \(articoli.count) articoli")
            .navigationDestination(for: Articolo.self) { DettaglioView(articolo: $0) }
            .toolbar { Button { nuovo = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $nuovo) { ArticoloForm(statoIniziale: .inVendita) }
        }
    }
}

struct Casella: View {
    var articolo: Articolo
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(articolo.stato.colore).frame(height: 4)
            Miniatura(articolo: articolo, lato: 56).padding(.horizontal, 10).padding(.top, 6)
            Text(articolo.nome).font(.subheadline.bold()).lineLimit(1).padding(.horizontal, 10)
            HStack {
                Text(articolo.stato.nomeSingolo).foregroundStyle(articolo.stato.colore)
                Spacer()
                Text(eur(articolo.prezzo)).foregroundStyle(.secondary)
            }
            .font(.caption).padding(.horizontal, 10).padding(.bottom, 10)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
