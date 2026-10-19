import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Dettaglio vendita

struct DettaglioView: View {
    @Bindable var articolo: Articolo
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var modifica = false
    @State private var elimina = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.1))
                    Miniatura(articolo: articolo, lato: articolo.foto == nil ? 80 : 200)
                }
                .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 16))

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
                    Tappa(fatto: articolo.venduto, titolo: "Venduto", data: articolo.dataVendita)
                    Tappa(fatto: articolo.dataSpedizione != nil, titolo: "Spedito", data: articolo.dataSpedizione,
                          nota: articolo.codiceSpedizione.isEmpty ? nil : "codice \(articolo.codiceSpedizione)")
                    Tappa(fatto: articolo.stato == .pagato, titolo: "Pagato", data: articolo.dataPagamento)
                }

                if let p = articolo.stato.prossimo {
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

// MARK: - Nuova vendita / modifica

struct ArticoloForm: View {
    var articolo: Articolo? = nil
    var statoIniziale: Stato = .daSpedire

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("siti") private var sitiTesto = "Vinted, Subito, eBay"
    @AppStorage("commissione") private var commissionePerc = 0.0

    @State private var nome = ""
    @State private var emoji = "👕"
    @State private var prezzo: Double? = nil
    @State private var costo: Double? = nil
    @State private var commissioni: Double? = nil
    @State private var sito = "Vinted"
    @State private var stato: Stato = .daSpedire
    @State private var data = Date()
    @State private var codice = ""
    @State private var foto: Data? = nil
    @State private var scelta: PhotosPickerItem? = nil
    @State private var caricato = false

    private let emojis = ["👕", "👖", "👗", "🧥", "👟", "👜", "🧶", "🧢", "👠", "🥾", "📚", "🎮", "📱", "🧸", "💍", "📦"]
    private var siti: [String] {
        sitiTesto.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var guadagno: Double { (prezzo ?? 0) - (costo ?? 0) - (commissioni ?? 0) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $scelta, matching: .images) {
                        if let f = foto, let img = UIImage(data: f) {
                            Image(uiImage: img).resizable().scaledToFill().frame(height: 140).frame(maxWidth: .infinity).clipped()
                        } else {
                            Label("Aggiungi foto", systemImage: "camera").frame(maxWidth: .infinity, minHeight: 60)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(emojis, id: \.self) { e in
                                Text(e).font(.title2).padding(4)
                                    .background(e == emoji ? Color.inchiostro.opacity(0.15) : .clear, in: Circle())
                                    .onTapGesture { emoji = e }
                            }
                        }
                    }
                }
                Section {
                    TextField("Articolo", text: $nome).accessibilityIdentifier("campoNome")
                    LabeledContent("Prezzo di vendita") {
                        TextField("0,00", value: $prezzo, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("campoPrezzo")
                    }
                    LabeledContent("Pagato da te") {
                        TextField("0,00", value: $costo, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Commissioni") {
                        TextField("0,00", value: $commissioni, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("Sito", selection: $sito) {
                        ForEach(siti.contains(sito) ? siti : siti + [sito], id: \.self) { Text($0) }
                    }
                    DatePicker("Data", selection: $data, displayedComponents: .date)
                }
                Section("Stato") {
                    Picker("Stato", selection: $stato) {
                        ForEach(Stato.allCases) { Text($0.nomeSingolo).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if stato.rawValue >= Stato.spedito.rawValue {
                        TextField("Codice di spedizione (facoltativo)", text: $codice)
                    }
                }
                Section {
                    LabeledContent("Guadagno stimato") {
                        Text(eur(guadagno)).bold().foregroundStyle(guadagno >= 0 ? .green : .red)
                    }
                }
            }
            .navigationTitle(articolo == nil ? (statoIniziale == .inVendita ? "Nuovo articolo" : "Nuova vendita") : "Modifica")
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
                if articolo == nil, commissionePerc > 0, let p { commissioni = Calcoli.commissione(prezzo: p, percentuale: commissionePerc) }
            }
            .onChange(of: scelta) { _, item in
                Task {
                    if let d = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: d) {
                        foto = img.ridotta(lato: 1200).jpegData(compressionQuality: 0.75)
                    }
                }
            }
        }
    }

    private func carica() {
        guard !caricato else { return }
        caricato = true
        if let a = articolo {
            nome = a.nome; emoji = a.emoji; prezzo = a.prezzo; costo = a.costo; commissioni = a.commissioni
            sito = a.sito; stato = a.stato; data = a.dataVendita ?? a.creato; codice = a.codiceSpedizione; foto = a.foto
        } else {
            stato = statoIniziale
            sito = siti.first ?? "Vinted"
        }
    }

    private func salva() {
        let a = articolo ?? Articolo()
        if articolo == nil { context.insert(a) }
        a.nome = nome.trimmingCharacters(in: .whitespaces)
        a.emoji = emoji
        a.prezzo = prezzo ?? 0
        a.costo = costo ?? 0
        a.commissioni = commissioni ?? 0
        a.sito = sito
        a.codiceSpedizione = codice
        a.foto = foto
        if articolo == nil { a.creato = data }
        if a.stato != stato { a.imposta(stato, il: stato == .daSpedire ? data : Date()) }
        if stato != .inVendita { a.dataVendita = data }
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
