import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            OrdiniView().tabItem { Label("Ordini", systemImage: "shippingbox") }
            ArticoliView().tabItem { Label("Articoli", systemImage: "tshirt") }
            StatisticheView().tabItem { Label("Statistiche", systemImage: "chart.bar") }
            AltroView().tabItem { Label("Altro", systemImage: "gearshape") }
        }
        .tint(.inchiostro)
    }
}

// MARK: - Ordini (Home)

struct OrdiniView: View {
    @Query(sort: \Articolo.creato, order: .reverse) private var articoli: [Articolo]
    @State private var nuova = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    riepilogo
                    ForEach([Stato.daSpedire, .spedito, .pagato]) { s in
                        Fila(stato: s, articoli: articoli.filter { $0.stato == s })
                    }
                    Button { nuova = true } label: {
                        Label("Nuova vendita", systemImage: "plus")
                            .font(.headline).frame(maxWidth: .infinity).padding()
                            .background(Color.inchiostro, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("nuovaVendita")
                }
                .padding()
            }
            .background(Color.sfondo)
            .navigationTitle("Ordini")
            .navigationDestination(for: Articolo.self) { DettaglioView(articolo: $0) }
            .sheet(isPresented: $nuova) { ArticoloForm(statoIniziale: .daSpedire) }
        }
    }

    private var riepilogo: some View {
        let mese = Date().formatted(.dateTime.month(.wide).locale(Locale(identifier: "it_IT"))).capitalized
        return HStack {
            Voce(titolo: mese, valore: eur(Calcoli.guadagnoMese(articoli, mese: Date())))
            Voce(titolo: "Da spedire", valore: "\(articoli.filter { $0.stato == .daSpedire }.count)", colore: .orange)
            Voce(titolo: "Da incassare", valore: eur(Calcoli.daIncassare(articoli)))
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct Voce: View {
    var titolo: String
    var valore: String
    var colore: Color = .inchiostro
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titolo).font(.caption).foregroundStyle(.secondary)
            Text(valore).font(.headline).foregroundStyle(colore).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Una fila di schede che si scorre di lato.
struct Fila: View {
    var stato: Stato
    var articoli: [Articolo]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(stato.colore).frame(width: 9, height: 9)
                Text(stato.nome).font(.headline).foregroundStyle(stato.colore)
                Text("(\(articoli.count))").font(.caption).foregroundStyle(.secondary)
            }
            if articoli.isEmpty {
                Text("Nessuno").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(articoli) { a in
                            NavigationLink(value: a) { Scheda(articolo: a) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct Scheda: View {
    var articolo: Articolo
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(articolo.stato.colore).frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Miniatura(articolo: articolo, lato: 22)
                    Text(articolo.nome).font(.subheadline.bold()).lineLimit(1)
                }
                Text(sottotitolo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(10)
            Spacer(minLength: 0)
        }
        .frame(width: 150)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sottotitolo: String {
        let d = (articolo.dataPagamento ?? articolo.dataSpedizione ?? articolo.dataVendita ?? articolo.creato)
            .formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT")))
        return "\(eur(articolo.prezzo)) · \(d)"
    }
}

struct Miniatura: View {
    var articolo: Articolo
    var lato: CGFloat
    var body: some View {
        if let d = articolo.foto, let img = UIImage(data: d) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: lato, height: lato).clipShape(RoundedRectangle(cornerRadius: lato / 5))
        } else {
            Text(articolo.emoji).font(.system(size: lato * 0.8)).frame(width: lato, height: lato)
        }
    }
}
