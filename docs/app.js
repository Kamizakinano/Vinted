"use strict";
// Vendite (web app): dati salvati in questo browser, backup in un file.
const VERSIONE = "2.2";
const CHIAVE = "vendite-dati", OPZ = "vendite-opzioni";
const STATI = [
  { nome: "In libreria", plur: "In libreria", col: "var(--grey)", btn: "Venduto" },
  { nome: "Da spedire", plur: "Da spedire", col: "var(--o)", btn: "Segna come spedito" },
  { nome: "Spedito", plur: "Spediti", col: "var(--b)", btn: "Segna come pagato" },
  { nome: "Pagato", plur: "Pagati", col: "var(--g)", btn: "" },
];
const $ = s => document.querySelector(s);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const eur = v => (v || 0).toLocaleString("it-IT", { style: "currency", currency: "EUR" });
const num = s => { const n = parseFloat(String(s ?? "").replace(/\s|€/g, "").replace(",", ".")); return isFinite(n) ? n : 0; };
const oggiISO = () => new Date().toISOString().slice(0, 10);
const dataBreve = iso => iso ? new Date(iso).toLocaleDateString("it-IT", { day: "numeric", month: "short" }) : "";

// ---------- Dati ----------
let articoli = [];
let opz = { siti: "Vinted, Subito, eBay", obiettivo: 150, comm: 0, ricorda: 7, ultimoBackup: null, cambiDopoBackup: 0 };
try { articoli = JSON.parse(localStorage.getItem(CHIAVE)) || []; } catch { articoli = []; }
try { Object.assign(opz, JSON.parse(localStorage.getItem(OPZ)) || {}); } catch {}
if (navigator.storage && navigator.storage.persist) navigator.storage.persist();

/** Salva in locale; se la sincronizzazione è attiva manda online gli articoli cambiati (o eliminati). */
function salva(cambiati = [], eliminati = []) {
  opz.cambiDopoBackup++;
  if (window.cloud) window.cloud.invia(cambiati, eliminati);
  localStorage.setItem(CHIAVE, JSON.stringify(articoli));
  salvaOpz();
  disegna();
}
function salvaOpz() { localStorage.setItem(OPZ, JSON.stringify(opz)); }
const siti = () => opz.siti.split(",").map(s => s.trim()).filter(Boolean);
const guadagno = a => (a.prezzo || 0) - (a.costo || 0) - (a.commissioni || 0);
const venduto = a => a.stato > 0;
const nuovoId = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);

/** Cambia stato e segna le date dei passaggi. */
function imposta(a, stato, data) {
  const ora = new Date().toISOString();
  a.stato = stato;
  if (stato === 0) { a.dataVendita = a.dataSpedizione = a.dataPagamento = null; return; }
  if (!a.dataVendita) a.dataVendita = data || ora;
  if (stato >= 2 && !a.dataSpedizione) a.dataSpedizione = ora;
  if (stato === 3 && !a.dataPagamento) a.dataPagamento = ora;
  if (stato < 3) a.dataPagamento = null;
  if (stato < 2) a.dataSpedizione = null;
}
const stessoMese = (iso, d) => { const x = new Date(iso); return x.getFullYear() === d.getFullYear() && x.getMonth() === d.getMonth(); };
const guadagnoMese = d => articoli.filter(a => venduto(a) && stessoMese(a.dataVendita || a.creato, d)).reduce((s, a) => s + guadagno(a), 0);
const daIncassare = () => articoli.filter(a => a.stato === 1 || a.stato === 2).reduce((s, a) => s + (a.prezzo || 0) - (a.commissioni || 0), 0);
const ordinati = () => [...articoli].sort((x, y) => (y.dataVendita || y.creato).localeCompare(x.dataVendita || x.creato));

// ---------- Schede ----------
document.querySelectorAll(".tabs button").forEach(b => b.onclick = () => {
  document.querySelectorAll(".tabs button").forEach(x => x.classList.toggle("on", x === b));
  document.querySelectorAll(".page").forEach(p => p.classList.toggle("on", p.id === "p-" + b.dataset.p));
  scrollTo(0, 0);
});

function disegna() { disegnaOrdini(); disegnaLibreria(); disegnaStat(); disegnaAltro(); }

function disegnaOrdini() {
  const mese = new Date().toLocaleDateString("it-IT", { month: "long" });
  $("#sumOrdini").innerHTML = `<div><small>${mese[0].toUpperCase() + mese.slice(1)}</small><b>${eur(guadagnoMese(new Date()))}</b></div>
    <div><small>Da spedire</small><b style="color:var(--o)">${articoli.filter(a => a.stato === 1).length}</b></div>
    <div><small>Da incassare</small><b>${eur(daIncassare())}</b></div>`;
  $("#file").innerHTML = [1, 2, 3].map(s => {
    const l = ordinati().filter(a => a.stato === s);
    return `<div class="sec"><div class="sech" style="color:${STATI[s].col}">● ${STATI[s].plur} <small>(${l.length})</small></div>
      ${l.length ? `<div class="row">${l.map(a => `<button class="cd" style="border-color:${STATI[s].col}" data-id="${a.id}">
        <b>${esc(a.nome)}</b><small>${eur(a.prezzo)} · ${dataBreve(a.dataPagamento || a.dataSpedizione || a.dataVendita)}</small></button>`).join("")}</div>`
        : `<div class="empty">Nessuno</div>`}</div>`;
  }).join("");
  const giorni = opz.ultimoBackup ? (Date.now() - new Date(opz.ultimoBackup)) / 864e5 : Infinity;
  const serve = opz.ricorda > 0 && articoli.length > 0 && opz.cambiDopoBackup > 0 && giorni >= opz.ricorda;
  $("#avvisoBackup").innerHTML = serve ? `<div class="warn">💾 <span>${opz.ultimoBackup ? `Ultimo backup ${Math.floor(giorni)} giorni fa` : "Non hai ancora fatto un backup"}</span><button id="backupOra">Salva</button></div>` : "";
  if (serve) $("#backupOra").onclick = salvaBackup;
}

function disegnaLibreria() {
  const lib = articoli.filter(a => !venduto(a)).sort((x, y) => y.creato.localeCompare(x.creato));
  $("#sumLib").innerHTML = `<div><small>Articoli</small><b>${lib.length}</b></div>
    <div><small>Hai speso</small><b>${eur(articoli.reduce((s, a) => s + (a.costo || 0), 0))}</b></div>
    <div><small>Venduti</small><b>${articoli.length - lib.length}</b></div>`;
  $("#lista").innerHTML = lib.length ? `<div class="box">${lib.map(a => `<div class="item">
      <button class="t" data-id="${a.id}"><b>${esc(a.nome)}</b><small>pagato ${eur(a.costo)} · ${dataBreve(a.creato)}</small></button>
      <button class="pill" data-vendi="${a.id}">Venduto</button></div>`).join("")}</div>`
    : `<div class="empty" style="text-align:center;padding:30px 16px">📚<br><b style="color:var(--ink)">Libreria vuota</b><br>Tocca ＋ per caricare un articolo e quanto l'hai pagato.</div>`;
}

function disegnaStat() {
  const oggi = new Date(), mesi = [];
  for (let k = 5; k >= 0; k--) { const d = new Date(oggi.getFullYear(), oggi.getMonth() - k, 1); mesi.push({ d, v: guadagnoMese(d) }); }
  const max = Math.max(1, ...mesi.map(m => m.v));
  const vend = articoli.filter(venduto);
  const sped = vend.filter(a => a.dataSpedizione).map(a => (new Date(a.dataSpedizione) - new Date(a.dataVendita)) / 864e5);
  const perSito = {};
  vend.forEach(a => perSito[a.sito || "—"] = (perSito[a.sito || "—"] || 0) + guadagno(a));
  $("#stat").innerHTML = `<div class="box" style="padding:12px 14px"><small>Guadagno ultimi 6 mesi</small>
      <div class="big">${eur(mesi.reduce((s, m) => s + m.v, 0))}</div>
      <div class="bars">${mesi.map((m, i) => `<div><i style="height:${Math.max(0, m.v) / max * 100}%;${i === 5 ? "background:var(--ink)" : ""}"></i>${m.d.toLocaleDateString("it-IT", { month: "short" })}</div>`).join("")}</div></div>
    <div class="lab">Dove sono gli articoli</div>
    <div class="box">${STATI.map((s, i) => `<div class="kv"><span style="color:${s.col}">● ${s.plur}</span><b>${articoli.filter(a => a.stato === i).length}</b></div>`).join("")}
      ${sped.length ? `<div class="kv"><span>Tempo medio di spedizione</span><b>${(sped.reduce((a, b) => a + b, 0) / sped.length).toLocaleString("it-IT", { maximumFractionDigits: 1 })} giorni</b></div>` : ""}</div>
    <div class="mini"><div class="box"><small>Vendite</small><b>${vend.length}</b></div>
      <div class="box"><small>Prezzo medio</small><b>${eur(vend.length ? vend.reduce((s, a) => s + a.prezzo, 0) / vend.length : 0)}</b></div></div>
    <div class="lab">Guadagno per sito</div>
    <div class="box">${Object.keys(perSito).length ? Object.keys(perSito).sort().map(s => `<div class="kv"><span>${esc(s)}</span><b>${eur(perSito[s])}</b></div>`).join("") : `<div class="kv"><span style="color:var(--sub)">Nessuna vendita</span></div>`}</div>`;
}

function disegnaAltro() {
  $("#optSiti").value = opz.siti;
  $("#optObiettivo").value = String(opz.obiettivo).replace(".", ",");
  $("#optComm").value = opz.comm ? String(opz.comm).replace(".", ",") : "";
  $("#optRicorda").value = String(opz.ricorda);
  $("#ultimoBackup").textContent = opz.ultimoBackup ? new Date(opz.ultimoBackup).toLocaleString("it-IT", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }) : "mai";
  $("#ultimoBackup").style.color = opz.ultimoBackup && opz.cambiDopoBackup === 0 ? "var(--g)" : "var(--o)";
  const fatto = guadagnoMese(new Date());
  $("#obiettivo").innerHTML = `<div style="padding:12px 0">Obiettivo: <b>${eur(fatto)}</b> su ${eur(opz.obiettivo)}
    <div class="prog"><i style="width:${Math.min(100, Math.max(0, fatto / Math.max(1, opz.obiettivo) * 100))}%"></i></div></div>`;
  $("#versione").textContent = "Vendite " + VERSIONE;
}
$("#optSiti").onchange = e => { opz.siti = e.target.value; salvaOpz(); };
$("#optObiettivo").onchange = e => { opz.obiettivo = num(e.target.value); salvaOpz(); disegnaAltro(); };
$("#optComm").onchange = e => { opz.comm = num(e.target.value); salvaOpz(); };
$("#optRicorda").onchange = e => { opz.ricorda = +e.target.value; salvaOpz(); disegnaOrdini(); };

// Tocchi su schede e pulsanti nelle liste
document.addEventListener("click", e => {
  const v = e.target.closest("[data-vendi]");
  if (v) return apriForm(articoli.find(a => a.id === v.dataset.vendi), { vendi: true });
  const d = e.target.closest("[data-id]");
  if (d) return apriDettaglio(d.dataset.id);
});
$("#nuovaVendita").onclick = () => apriForm(null, { stato: 1 });
$("#nuovoArticolo").onclick = () => apriForm(null, { stato: 0 });
$("#apriCerca").onclick = apriCerca;

// ---------- Fogli (finestre che salgono dal basso) ----------
const pila = [];
function apriFoglio(html, dopo) {
  pila.push({ html, dopo });
  mostraFoglio();
}
function mostraFoglio() {
  const s = $("#sheet"), top = pila[pila.length - 1];
  if (!top) { s.classList.remove("on"); document.body.style.overflow = ""; return; }
  s.innerHTML = top.html(); s.scrollTop = 0;
  document.body.style.overflow = "hidden";
  requestAnimationFrame(() => s.classList.add("on"));
  top.dopo && top.dopo(s);
}
function chiudiFoglio() { pila.pop(); mostraFoglio(); }

function apriDettaglio(id) {
  const html = () => {
    const a = articoli.find(x => x.id === id);
    if (!a) return "";
    const st = STATI[a.stato];
    const tappa = (ok, t, d, nota) => `<div class="step"><span class="dot" style="background:${ok ? "var(--g)" : "#d0d4dc"}">${ok ? "✓" : ""}</span><div><b>${t}</b><br><small>${d ? new Date(d).toLocaleString("it-IT", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }) : ""}${nota ? " · " + esc(nota) : ""}</small></div></div>`;
    return `<div class="nav"><button data-a="chiudi">‹ Indietro</button><button data-a="modifica">Modifica</button></div>
      <h1 style="margin:6px 0 8px">${esc(a.nome)}</h1>
      <span class="tag" style="color:${st.col};background:color-mix(in srgb, ${st.col} 15%, transparent)">● ${st.nome}</span>
      <div class="box" style="margin-top:12px">
        <div class="kv"><span>Pagato da te</span><b>${eur(a.costo)}</b></div>
        ${venduto(a) ? `<div class="kv"><span>Venduto a</span><b>${eur(a.prezzo)}</b></div>
        <div class="kv"><span>Commissioni</span><b>${eur(-(a.commissioni || 0))}</b></div>
        <div class="kv"><span>Sito</span><b>${esc(a.sito)}</b></div>
        <div class="kv"><span>Guadagno</span><b style="color:${guadagno(a) >= 0 ? "var(--g)" : "var(--red)"}">${eur(guadagno(a))}</b></div>` : ""}
      </div>
      <div class="box">${tappa(true, "Caricato", a.creato)}${tappa(venduto(a), "Venduto", a.dataVendita)}${tappa(!!a.dataSpedizione, "Spedito", a.dataSpedizione, a.codice)}${tappa(a.stato === 3, "Pagato", a.dataPagamento)}</div>
      ${st.btn ? `<button class="btn" data-a="avanza" style="background:${STATI[Math.min(3, a.stato + 1)].col}">${st.btn}</button>` : ""}
      <button class="del" data-a="elimina">Elimina</button>`;
  };
  apriFoglio(html, s => s.onclick = e => {
    const b = e.target.closest("[data-a]"); if (!b) return;
    const a = articoli.find(x => x.id === id);
    if (b.dataset.a === "chiudi") chiudiFoglio();
    if (b.dataset.a === "modifica") apriForm(a, {});
    if (b.dataset.a === "avanza") { if (a.stato === 0) apriForm(a, { vendi: true }); else { imposta(a, a.stato + 1); salva([a]); mostraFoglio(); } }
    if (b.dataset.a === "elimina" && confirm(`Eliminare "${a.nome}"?`)) { articoli = articoli.filter(x => x !== a); salva([], [a.id]); chiudiFoglio(); }
  });
}

/** Nuova vendita, nuovo articolo, "Venduto" dalla libreria o modifica. */
function apriForm(art, { stato = 1, vendi = false }) {
  const nuovo = !art;
  const f = {
    nome: art?.nome || "", costo: art?.costo, prezzo: vendi ? undefined : art?.prezzo,
    comm: vendi ? undefined : art?.commissioni, sito: (!vendi && art?.sito) || siti()[0] || "Vinted",
    stato: vendi ? 1 : art ? art.stato : stato, codice: art?.codice || "",
    data: (!vendi && art ? (art.stato ? art.dataVendita : art.creato) : null)?.slice(0, 10) || oggiISO(), scelto: null,
  };
  const soloLibreria = nuovo && stato === 0;
  const titolo = vendi ? art.nome : art ? "Modifica" : soloLibreria ? "Nuovo articolo" : "Nuova vendita";
  const libreria = () => articoli.filter(a => !venduto(a));
  const n = v => v == null ? "" : String(v).replace(".", ",");
  const html = () => {
    const vend = f.stato > 0, sl = siti().includes(f.sito) ? siti() : [...siti(), f.sito];
    return `<div class="nav"><button data-a="annulla">Annulla</button><span class="tt">${esc(titolo)}</span><button class="ok" data-a="salva" id="ok">Salva</button></div>
      ${nuovo && !soloLibreria && libreria().length ? `<div class="box"><div class="kv"><button style="color:var(--b);width:100%;text-align:left" data-a="libreria">📚 ${f.scelto ? "Dalla libreria: " + esc(f.scelto.nome) : "Scegli dalla libreria ›"}</button></div></div>` : ""}
      <div class="box">
        <div class="kv"><span>Articolo</span><input id="fNome" value="${esc(f.nome)}" placeholder="Nome" autocomplete="off"></div>
        <div class="kv"><span>Pagato da te</span><input id="fCosto" inputmode="decimal" value="${n(f.costo)}" placeholder="0,00 €"></div>
        ${vend ? `<div class="kv"><span>${vendi ? "Venduto a" : "Prezzo di vendita"}</span><input id="fPrezzo" inputmode="decimal" value="${n(f.prezzo)}" placeholder="0,00 €"></div>
        <div class="kv"><span>Commissioni</span><input id="fComm" inputmode="decimal" value="${n(f.comm)}" placeholder="0,00 €"></div>
        <div class="kv"><span>Sito</span><select id="fSito">${sl.map(s => `<option ${s === f.sito ? "selected" : ""}>${esc(s)}</option>`).join("")}</select></div>` : ""}
        <div class="kv"><span>${vend ? "Venduto il" : "Caricato il"}</span><input type="date" id="fData" value="${f.data}"></div>
      </div>
      ${soloLibreria ? "" : `<div class="lab">${vendi ? "A che punto sei" : "Stato"}</div>
      <div class="seg">${STATI.map((s, i) => vendi && i === 0 ? "" : `<button data-st="${i}" class="${f.stato === i ? "on" : ""}" style="${f.stato === i ? `background:${s.col};color:#fff` : ""}">${s.nome}</button>`).join("")}</div>
      ${f.stato >= 2 ? `<div class="box"><div class="kv"><span>Codice spedizione</span><input id="fCodice" value="${esc(f.codice)}" placeholder="facoltativo"></div></div>` : ""}`}
      ${vend ? `<div class="box"><div class="kv"><span>Guadagno</span><b id="fGuad"></b></div></div>` : ""}`;
  };
  const leggi = () => {
    const v = id => $("#" + id)?.value;
    f.nome = v("fNome") ?? f.nome; f.costo = $("#fCosto") && v("fCosto") !== "" ? num(v("fCosto")) : f.costo;
    if ($("#fPrezzo")) f.prezzo = v("fPrezzo") === "" ? undefined : num(v("fPrezzo"));
    if ($("#fComm")) f.comm = v("fComm") === "" ? undefined : num(v("fComm"));
    if ($("#fSito")) f.sito = v("fSito");
    if ($("#fData")) f.data = v("fData") || oggiISO();
    if ($("#fCodice")) f.codice = v("fCodice");
  };
  const aggiorna = () => {
    $("#ok").disabled = !$("#fNome").value.trim();
    if ($("#fGuad")) {
      const g = num($("#fPrezzo").value) - num($("#fCosto").value) - num($("#fComm").value);
      $("#fGuad").textContent = eur(g); $("#fGuad").style.color = g >= 0 ? "var(--g)" : "var(--red)";
    }
  };
  apriFoglio(html, s => {
    aggiorna();
    s.oninput = e => {
      if (e.target.id === "fPrezzo" && opz.comm > 0 && (nuovo || vendi)) {
        $("#fComm").value = n(Math.round(num(e.target.value) * opz.comm) / 100);
      }
      aggiorna();
    };
    s.onclick = e => {
      const st = e.target.closest("[data-st]");
      if (st) { leggi(); f.stato = +st.dataset.st; mostraFoglio(); return; }
      const b = e.target.closest("[data-a]"); if (!b) return;
      if (b.dataset.a === "annulla") chiudiFoglio();
      if (b.dataset.a === "libreria") { leggi(); scegliDaLibreria(a => { f.scelto = a; f.nome = a.nome; f.costo = a.costo; }); }
      if (b.dataset.a === "salva") {
        leggi();
        const a = art || f.scelto || { id: nuovoId(), creato: new Date(f.data + "T12:00:00").toISOString(), stato: 0 };
        if (!art && !f.scelto) articoli.push(a);
        a.nome = f.nome.trim(); a.costo = f.costo || 0; a.codice = f.codice;
        if (f.stato > 0) { a.prezzo = f.prezzo || 0; a.commissioni = f.comm || 0; a.sito = f.sito; }
        const dataISO = new Date(f.data + "T12:00:00").toISOString();
        if (a.stato !== f.stato) imposta(a, f.stato, dataISO);
        if (f.stato > 0) a.dataVendita = dataISO; else if (art) a.creato = dataISO;
        salva([a]); chiudiFoglio(); if (pila.length) mostraFoglio();
        toast(f.stato > 0 ? "Vendita salvata" : "Articolo in libreria");
      }
    };
  });
}

function scegliDaLibreria(fatto) {
  apriFoglio(() => `<div class="nav"><button data-a="chiudi">‹ Indietro</button><span class="tt">Libreria</span><span style="width:60px"></span></div>
    <div class="box">${articoli.filter(a => !venduto(a)).map(a => `<button class="item" style="width:100%" data-sc="${a.id}"><span class="t"><b>${esc(a.nome)}</b><small>pagato ${eur(a.costo)}</small></span>›</button>`).join("")}</div>`,
    s => s.onclick = e => {
      const c = e.target.closest("[data-sc]");
      if (c) { fatto(articoli.find(a => a.id === c.dataset.sc)); chiudiFoglio(); }
      else if (e.target.closest("[data-a]")) chiudiFoglio();
    });
}

function apriCerca() {
  let testo = "", filtro = 0;
  const risultati = () => ordinati().filter(a => (filtro === 0 || (filtro === 1 && !venduto(a)) || (filtro === 2 && venduto(a)))
    && (!testo.trim() || a.nome.toLowerCase().includes(testo.trim().toLowerCase())));
  const lista = () => { const r = risultati(); return `<div class="lab">${r.length} risultati</div><div class="box">${r.map(a => `<button class="item" style="width:100%" data-id="${a.id}">
      <span class="t"><b>${esc(a.nome)}</b><small>pagato ${eur(a.costo)}${venduto(a) ? " · venduto " + eur(a.prezzo) : ""}</small></span>
      <small style="color:${STATI[a.stato].col};font-weight:700">● ${STATI[a.stato].nome}</small></button>`).join("")}</div>`; };
  apriFoglio(() => `<div class="nav"><span class="tt">Cerca</span><button data-a="chiudi">Chiudi</button></div>
      <input class="srch" id="cTesto" type="search" placeholder="🔍 Cerca per nome" value="${esc(testo)}">
      <div class="seg">${["Tutti", "Libreria", "Venduti"].map((t, i) => `<button data-f="${i}" class="${filtro === i ? "on" : ""}">${t}</button>`).join("")}</div>
      <div id="cLista">${lista()}</div>`,
    s => {
      setTimeout(() => $("#cTesto")?.focus(), 300);
      s.oninput = e => { if (e.target.id === "cTesto") { testo = e.target.value; $("#cLista").innerHTML = lista(); } };
      s.onclick = e => {
        const fb = e.target.closest("[data-f]");
        if (fb) { filtro = +fb.dataset.f; s.querySelectorAll("[data-f]").forEach(x => x.classList.toggle("on", x === fb)); $("#cLista").innerHTML = lista(); return; }
        const r = e.target.closest("[data-id]");
        if (r) { e.stopPropagation(); return apriDettaglio(r.dataset.id); }
        if (e.target.closest("[data-a]")) chiudiFoglio();
      };
    });
}
// I tocchi dentro il foglio non devono arrivare anche al gestore generale.
$("#sheet").addEventListener("click", e => e.stopPropagation());

// ---------- File: backup, ripristino, esportazione ----------
async function condividi(nome, blob) {
  const file = new File([blob], nome, { type: blob.type });
  if (navigator.canShare && navigator.canShare({ files: [file] })) {
    try { await navigator.share({ files: [file] }); return true; }
    catch (e) { if (e.name === "AbortError") return false; }
  }
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob); a.download = nome;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  return true;
}
async function salvaBackup() {
  const dati = { app: "Vendite", versione: 1, salvato: new Date().toISOString(), opzioni: { siti: opz.siti, obiettivo: opz.obiettivo, comm: opz.comm }, articoli };
  const ok = await condividi(`Vendite-backup-${oggiISO()}.json`, new Blob([JSON.stringify(dati, null, 1)], { type: "application/json" }));
  if (ok) { opz.ultimoBackup = new Date().toISOString(); opz.cambiDopoBackup = 0; salvaOpz(); disegna(); toast("Backup pronto: salvalo in File"); }
}
$("#salvaBackup").onclick = salvaBackup;
$("#fileRipristino").onchange = async e => {
  const file = e.target.files[0]; e.target.value = "";
  if (!file) return;
  try {
    const d = JSON.parse(await file.text());
    if (!Array.isArray(d.articoli)) throw 0;
    if (!confirm(`Il backup del ${new Date(d.salvato).toLocaleString("it-IT")} contiene ${d.articoli.length} articoli.\nSostituisce i dati di adesso. Continuare?`)) return;
    const vecchi = articoli.map(a => a.id).filter(id => !d.articoli.some(a => a.id === id));
    articoli = d.articoli;
    Object.assign(opz, d.opzioni || {});
    opz.ultimoBackup = d.salvato; salva(articoli, vecchi); opz.cambiDopoBackup = 0; salvaOpz(); disegna();
    toast("Backup ripristinato");
  } catch { alert("Questo file non è un backup di Vendite."); }
};

const righeTabella = () => [["Articolo", "Stato", "Sito", "Caricato il", "Venduto il", "Pagato da te", "Venduto a", "Commissioni", "Guadagno"],
  ...ordinati().map(a => [a.nome, STATI[a.stato].nome, venduto(a) ? a.sito : "", new Date(a.creato), a.dataVendita ? new Date(a.dataVendita) : "",
    a.costo || 0, venduto(a) ? a.prezzo || 0 : "", venduto(a) ? a.commissioni || 0 : "", venduto(a) ? guadagno(a) : ""])];

$("#esportaCsv").onclick = () => {
  const c = v => v instanceof Date ? v.toLocaleDateString("it-IT") : typeof v === "number" ? v.toFixed(2).replace(".", ",") : `"${String(v).replace(/"/g, '""')}"`;
  const testo = "﻿" + righeTabella().map(r => r.map(c).join(";")).join("\r\n");
  condividi(`Vendite ${oggiISO()}.csv`, new Blob([testo], { type: "text/csv" }));
};
$("#esportaXlsx").onclick = () => {
  const vend = righeTabella().filter((r, i) => i === 0 || r[1] !== STATI[0].nome);
  const lib = [["Articolo", "Caricato il", "Pagato da te"], ...articoli.filter(a => !venduto(a)).map(a => [a.nome, new Date(a.creato), a.costo || 0])];
  const somma = (rows, col) => rows.slice(1).reduce((s, r) => s + (typeof r[col] === "number" ? r[col] : 0), 0);
  vend.push(["Totale", "", "", "", "", somma(vend, 5), somma(vend, 6), somma(vend, 7), somma(vend, 8)]);
  lib.push(["Totale", "", somma(lib, 2)]);
  const blob = creaXlsx([{ nome: "Vendite", righe: vend, larg: [24, 12, 10, 12, 12, 13, 12, 13, 12] }, { nome: "Libreria", righe: lib, larg: [24, 12, 13] }]);
  condividi(`Vendite ${oggiISO()}.xlsx`, blob);
};

// .xlsx scritto a mano: uno zip (senza compressione) con i fogli in XML.
function creaXlsx(fogli) {
  const x = s => esc(s);
  const col = i => String.fromCharCode(65 + i);
  const giorno = d => (Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(1899, 11, 30)) / 864e5;
  const foglio = f => `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>${f.larg.map((w, i) => `<col min="${i + 1}" max="${i + 1}" width="${w}" customWidth="1"/>`).join("")}</cols><sheetData>${f.righe.map((r, ri) => {
    const ultima = ri === f.righe.length - 1 && ri > 0;
    return `<row r="${ri + 1}">${r.map((v, ci) => {
      const ref = col(ci) + (ri + 1);
      if (ri === 0) return `<c r="${ref}" t="inlineStr" s="1"><is><t>${x(v)}</t></is></c>`;
      if (v instanceof Date) return `<c r="${ref}" s="2"><v>${giorno(v)}</v></c>`;
      if (typeof v === "number") return `<c r="${ref}" s="${ultima ? 4 : 3}"><v>${Math.round(v * 100) / 100}</v></c>`;
      return v === "" ? "" : `<c r="${ref}" t="inlineStr"${ultima ? ' s="5"' : ""}><is><t>${x(v)}</t></is></c>`;
    }).join("")}</row>`;
  }).join("")}</sheetData></worksheet>`;
  const file = {
    "[Content_Types].xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${fogli.map((f, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join("")}</Types>`,
    "_rels/.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    "xl/workbook.xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${fogli.map((f, i) => `<sheet name="${x(f.nome)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join("")}</sheets></workbook>`,
    "xl/_rels/workbook.xml.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${fogli.map((f, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join("")}<Relationship Id="rId${fogli.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
    "xl/styles.xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/><numFmt numFmtId="165" formatCode="#,##0.00\\ &quot;€&quot;"/></numFmts><fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1D2433"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="6"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="165" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>`,
  };
  fogli.forEach((f, i) => file[`xl/worksheets/sheet${i + 1}.xml`] = foglio(f));
  return new Blob([zip(file)], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
}
function crc32(b) {
  let c, t = crc32.t;
  if (!t) { t = crc32.t = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } }
  c = 0xFFFFFFFF;
  for (let i = 0; i < b.length; i++) c = t[(c ^ b[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}
function zip(file) {
  const enc = new TextEncoder(), parti = [], centrale = [];
  let off = 0;
  const u16 = v => [v & 255, (v >> 8) & 255], u32 = v => [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >>> 24) & 255];
  for (const [nome, testo] of Object.entries(file)) {
    const n = enc.encode(nome), d = enc.encode(testo), crc = crc32(d);
    const comune = [...u16(20), ...u16(0x0800), ...u16(0), ...u16(0), ...u16(0x21), ...u32(crc), ...u32(d.length), ...u32(d.length), ...u16(n.length), ...u16(0)];
    const loc = new Uint8Array([...u32(0x04034b50), ...comune]);
    parti.push(loc, n, d);
    centrale.push(new Uint8Array([...u32(0x02014b50), ...u16(20), ...comune, ...u16(0), ...u16(0), ...u16(0), ...u32(0), ...u32(off)]), n);
    off += loc.length + n.length + d.length;
  }
  const lungC = centrale.reduce((s, p) => s + p.length, 0);
  const fine = new Uint8Array([...u32(0x06054b50), ...u16(0), ...u16(0), ...u16(Object.keys(file).length), ...u16(Object.keys(file).length), ...u32(lungC), ...u32(off), ...u16(0)]);
  return new Blob([...parti, ...centrale, fine]);
}

function toast(t) { const el = $("#toast"); el.textContent = t; el.classList.add("on"); clearTimeout(toast.h); toast.h = setTimeout(() => el.classList.remove("on"), 2200); }

/** Usato dalla sincronizzazione quando arrivano dati da un altro dispositivo. */
window.vendite = {
  get articoli() { return articoli; },
  sostituisci(lista) { articoli = lista; localStorage.setItem(CHIAVE, JSON.stringify(articoli)); disegna(); if (pila.length && !$("#fNome") && !$("#cTesto")) mostraFoglio(); },
  toast,
};

if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js");
disegna();
