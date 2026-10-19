import SwiftUI
import SwiftData

// MARK: - Dettaglio vendita

struct DettaglioView: View {
    @Bindable var articolo: Articolo
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var modifica = false
    @State private var elimina = false
    @State private var vendi = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if articolo.foto != nil {
                    Miniatura(articolo: articolo, lato: 200).frame(maxWidth: .infinity)
                }

                Text(articolo.nome).font(.largeTitle.bold())
                HStack(spacing: 4) {
                    Circle().fill(articolo.stato.colore).frame(width: 8, height: 8)
                    Text(articolo.stato.nomeSingolo).font(.subheadline.bold())
                }
                .foregroundStyle(articolo.stato.colore)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(articolo.stato.colore.opacity(0.15), in: Capsule())

                Riquadro {
                    Riga("Prezzo", eur(articolo.prezzo))
                    Riga("Pagato da te", eur(articolo.costo))
                    Riga("Commissioni", eur(-articolo.commissioni))
                    Riga("Sito", articolo.sito)
                    Riga("Guadagno", eur(articolo.guadagno), colore: articolo.guadagno >= 0 ? .green : .red)
                }

                Riquadro {
                    Tappa(fatto: true, titolo: "Caricato", data: articolo.creato)
                    Tappa(fatto: articolo.venduto, titolo: "Venduto", data: articolo.dataVendita)
                    Tappa(fatto: articolo.dataSpedizione != nil, titolo: "Spedito", data: articolo.dataSpedizione,
                          nota: articolo.codiceSpedizione.isEmpty ? nil : "codice \(articolo.codiceSpedizione)")
                    Tappa(fatto: articolo.stato == .pagato, titolo: "Pagato", data: articolo.dataPagamento)
                }

                if articolo.stato == .inVendita {
                    Button { vendi = true } label: {
                        Text("Venduto").font(.headline).frame(maxWidth: .infinity).padding()
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                    }
                } else if let p = articolo.stato.prossimo {
                    Button {
                        withAnimation { articolo.imposta(p) }
                    } label: {
                        Text(articolo.stato.pulsante).font(.headline).frame(maxWidth: .infinity).padding()
                            .background(p.colore, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("avanza")
                }
                Button("Elimina", role: .destructive) { elimina = true }
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding()
        }
        .background(Color.sfondo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Modifica") { modifica = true } }
        .sheet(isPresented: $modifica) { ArticoloForm(articolo: articolo) }
        .sheet(isPresented: $vendi) { ArticoloForm(articolo: articolo, vendi: true) }
        .confirmationDialog("Eliminare \(articolo.nome)?", isPresented: $elimina, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { context.delete(articolo); dismiss() }
        }
    }
}

struct Riquadro<C: View>: View {
    @ViewBuilder var contenuto: C
    var body: some View {
        VStack(spacing: 0) { contenuto }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct Riga: View {
    var titolo: String, valore: String, colore: Color
    init(_ t: String, _ v: String, colore: Color = .primary) { titolo = t; valore = v; self.colore = colore }
    var body: some View {
        HStack { Text(titolo); Spacer(); Text(valore).bold().foregroundStyle(colore) }
            .padding(.vertical, 9)
    }
}

struct Tappa: View {
    var fatto: Bool, titolo: String, data: Date?
    var nota: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: fatto ? "checkmark.circle.fill" : "circle")
                .font(.title2).foregroundStyle(fatto ? .green : .gray.opacity(0.5))
            VStack(alignment: .leading) {
                Text(titolo).bold()
                if let d = data {
                    Text(d.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "it_IT")))
                         + (nota.map { " · " + $0 } ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Nuova vendita / articolo / modifica

struct ArticoloForm: View {
    var articolo: Articolo? = nil
    var statoIniziale: Stato = .daSpedire
    /// true quando si tocca "Venduto" su un articolo della libreria.
    var vendi = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("siti") private var sitiTesto = "Vinted, Subito, eBay"
    @AppStorage("commissione") private var commissionePerc = 0.0
    @Query(sort: \Articolo.creato, order: .reverse) private var tutti: [Articolo]

    @State private var scelto: Articolo? = nil
    @State private var nome = ""
    @State private var prezzo: Double? = nil
    @State private var costo: Double? = nil
    @State private var commissioni: Double? = nil
    @State private var sito = "Vinted"
    @State private var stato: Stato = .daSpedire
    @State private var data = Date()
    @State private var codice = ""
    @State private var caricato = false
    @State private var mostraLibreria = false

    private var siti: [String] {
        sitiTesto.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var inLibreria: [Articolo] { tutti.filter { !$0.venduto } }
    private var guadagno: Double { (prezzo ?? 0) - (costo ?? 0) - (commissioni ?? 0) }
    private var titolo: String {
        if vendi, let a = articolo { return a.nome }
        if articolo != nil { return "Modifica" }
        return statoIniziale == .inVendita ? "Nuovo articolo" : "Nuova vendita"
    }

    var body: some View {
        NavigationStack {
            Form {
                if articolo == nil, statoIniziale != .inVendita, !inLibreria.isEmpty {
                    Section {
                        Button { mostraLibreria = true } label: {
                            Label(scelto == nil ? "Scegli dalla libreria" : "Dalla libreria: \(scelto!.nome)", systemImage: "books.vertical")
                        }
                        .accessibilityIdentifier("scegliLibreria")
                    }
                }
                Section {
                    TextField("Articolo", text: $nome).accessibilityIdentifier("campoNome")
                    campo("Pagato da te", $costo, id: "campoCosto")
                    if stato != .inVendita {
                        campo(vendi ? "Venduto a" : "Prezzo di vendita", $prezzo, id: "campoPrezzo")
                        campo("Commissioni", $commissioni, id: "campoCommissioni")
                        Picker("Sito", selection: $sito) {
                            ForEach(siti.contains(sito) ? siti : siti + [sito], id: \.self) { Text($0) }
                        }
                    }
                    DatePicker(stato == .inVendita ? "Caricato il" : "Venduto il", selection: $data, displayedComponents: .date)
                }
                if !(articolo == nil && statoIniziale == .inVendita) {
                    Section(vendi ? "A che punto sei" : "Stato") {
                        Picker("Stato", selection: $stato) {
                            ForEach(Stato.allCases.filter { !vendi || $0 != .inVendita }) { Text($0.nomeSingolo).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if stato.rawValue >= Stato.spedito.rawValue {
                            TextField("Codice di spedizione (facoltativo)", text: $codice)
                        }
                    }
                }
                if stato != .inVendita {
                    Section {
                        LabeledContent("Guadagno") {
                            Text(eur(guadagno)).bold().foregroundStyle(guadagno >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle(titolo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { salva() }.disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("salva")
                }
            }
            .onAppear(perform: carica)
            .onChange(of: prezzo) { _, p in
                // Commissioni proposte in automatico, se impostate in Altro.
                if (articolo == nil || vendi), commissionePerc > 0, let p { commissioni = Calcoli.commissione(prezzo: p, percentuale: commissionePerc) }
            }
            .sheet(isPresented: $mostraLibreria) {
                NavigationStack {
                    List(inLibreria) { a in
                        Button {
                            scelto = a; nome = a.nome; costo = a.costo; mostraLibreria = false
                        } label: {
                            VStack(alignment: .leading) {
                                Text(a.nome).bold().foregroundStyle(Color.primary)
                                Text("pagato \(eur(a.costo))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Libreria")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Chiudi") { mostraLibreria = false } }
                }
            }
        }
    }

    private func campo(_ titolo: String, _ valore: Binding<Double?>, id: String) -> some View {
        LabeledContent(titolo) {
            TextField("0,00", value: valore, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
        }
    }

    private func carica() {
        guard !caricato else { return }
        caricato = true
        sito = siti.first ?? "Vinted"
        if let a = articolo {
            nome = a.nome; costo = a.costo; codice = a.codiceSpedizione
            if vendi {
                stato = .daSpedire
                data = Date()
            } else {
                prezzo = a.prezzo; commissioni = a.commissioni; sito = a.sito
                stato = a.stato; data = a.dataVendita ?? a.creato
            }
        } else {
            stato = statoIniziale
        }
    }

    private func salva() {
        let a = articolo ?? scelto ?? Articolo()
        if articolo == nil && scelto == nil { context.insert(a); a.creato = data }
        a.nome = nome.trimmingCharacters(in: .whitespaces)
        a.costo = costo ?? 0
        if stato != .inVendita {
            a.prezzo = prezzo ?? 0
            a.commissioni = commissioni ?? 0
            a.sito = sito
        }
        a.codiceSpedizione = codice
        if a.stato != stato { a.imposta(stato, il: stato == .daSpedire ? data : Date()) }
        if stato != .inVendita { a.dataVendita = data } else if articolo != nil { a.creato = data }
        dismiss()
    }
}

extension UIImage {
    func ridotta(lato: CGFloat) -> UIImage {
        let s = min(1, lato / max(size.width, size.height))
        guard s < 1 else { return self }
        let n = CGSize(width: size.width * s, height: size.height * s)
        return UIGraphicsImageRenderer(size: n).image { _ in draw(in: CGRect(origin: .zero, size: n)) }
    }
}
