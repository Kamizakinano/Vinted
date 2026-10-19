# Vendite: istruzioni per Claude

App iOS (SwiftUI, SwiftData, iOS 17+) per tenere traccia di vendite e guadagni (Vinted, Subito, eBay). Stile scelto: "Stati a colonne" (Da spedire arancione, Spediti blu, Pagati verde, colore scuro 1D2433). Il proprietario la installa con Sideloadly e non programma: rispondi in italiano, in breve, con anteprime delle schermate (iPhone con Dynamic Island) per ogni proposta.

- Versione in `project.yml` (`MARKETING_VERSION`): ogni modifica è una versione nuova (1.0 → 1.1).
- Il push su `claude/**` avvia la CI (circa 10-15 minuti): prove sul simulatore, poi `Vendite.ipa` nella release `ultima-versione`. Mandala come "Vendite vX.Y.ipa". Mai mandare un'IPA se le prove falliscono; errori dalle annotazioni del check-run.
- Codice: `VenditeApp.swift` (modello `Articolo`, `Stato`, `Calcoli`), `ContentView.swift` (schede, Ordini), `Dettaglio.swift` (dettaglio, nuova vendita), `Schede.swift` (Libreria, Ricerca, Statistiche, Altro). Proprietà nuove del modello sempre con valore di default. Prove in `VenditeTests/` e `VenditeUITests/`.
