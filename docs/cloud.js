// Sincronizzazione tra dispositivi con Firebase (accesso con email e password, dati in Firestore).
import { firebaseConfig } from "./firebase-config.js";

const V = "10.12.2", URL = `https://www.gstatic.com/firebasejs/${V}/`;
const $ = s => document.querySelector(s);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function stato(html) { $("#sync").innerHTML = html; }

async function avvia() {
  if (!firebaseConfig) {
    stato(`<div class="kv"><span style="color:var(--sub)">Non ancora attiva: i dati stanno solo su questo dispositivo.</span></div>`);
    return;
  }
  stato(`<div class="kv"><span style="color:var(--sub)">Collegamento…</span></div>`);
  const [{ initializeApp }, A, F] = await Promise.all([
    import(URL + "firebase-app.js"), import(URL + "firebase-auth.js"), import(URL + "firebase-firestore.js"),
  ]);
  const app = initializeApp(firebaseConfig);
  const auth = A.getAuth(app);
  await A.setPersistence(auth, A.browserLocalPersistence);
  const db = F.initializeFirestore(app, { localCache: F.persistentLocalCache() });
  const col = F.collection(db, "articoli");
  let stacca = null;

  window.cloud = {
    invia(cambiati, eliminati) {
      if (!auth.currentUser) return;
      const b = F.writeBatch(db);
      cambiati.forEach(a => b.set(F.doc(col, a.id), JSON.parse(JSON.stringify(a))));
      eliminati.forEach(id => b.delete(F.doc(col, id)));
      b.commit().catch(e => window.vendite.toast("Errore di sincronizzazione: " + e.code));
    },
  };

  A.onAuthStateChanged(auth, async utente => {
    if (stacca) { stacca(); stacca = null; }
    if (!utente) return mostraAccesso();
    stato(`<div class="kv"><span>Sincronizzazione</span><b style="color:var(--g)">attiva ✓</b></div>
      <div class="kv"><span>Account</span><b style="font-weight:500">${esc(utente.email)}</b></div>
      <div class="kv"><span id="syncInfo" style="color:var(--sub)">In attesa dei dati…</span><button style="color:var(--red)" id="esci">Esci</button></div>`);
    $("#esci").onclick = () => confirm("Uscire? I dati restano su questo dispositivo ma non si sincronizzano più.") && A.signOut(auth);
    let primo = true;
    stacca = F.onSnapshot(col, async snap => {
      const online = snap.docs.map(d => d.data());
      if (primo) {
        primo = false;
        // Al primo accesso: manda online gli articoli che c'erano solo su questo dispositivo.
        const soloQui = window.vendite.articoli.filter(a => !online.some(o => o.id === a.id));
        if (soloQui.length) { window.cloud.invia(soloQui, []); online.push(...soloQui); }
      }
      window.vendite.sostituisci(online);
      const info = $("#syncInfo");
      if (info) info.textContent = (snap.metadata.fromCache ? "Senza internet: invio appena torna" : "Aggiornato") + " · " + new Date().toLocaleTimeString("it-IT", { hour: "2-digit", minute: "2-digit" });
    }, e => {
      stato(`<div class="kv"><span style="color:var(--red)">Accesso ai dati negato (${esc(e.code)}). Questo account non è tra quelli autorizzati.</span><button style="color:var(--b)" id="esci2">Esci</button></div>`);
      $("#esci2").onclick = () => A.signOut(auth);
    });
  });

  function mostraAccesso() {
    stato(`<div class="kv"><span>Email</span><input id="sEmail" type="email" autocomplete="username" placeholder="nome@gmail.com"></div>
      <div class="kv"><span>Password</span><input id="sPass" type="password" autocomplete="current-password" placeholder="almeno 6 caratteri"></div>
      <div class="kv"><button style="color:var(--b);font-weight:700" id="accedi">Accedi</button><button style="color:var(--b)" id="crea">Crea account</button></div>
      <div class="kv"><button style="color:var(--sub);font-size:14px" id="dimenticata">Password dimenticata?</button></div>`);
    const prova = async fn => {
      try { await fn(auth, $("#sEmail").value.trim(), $("#sPass").value); }
      catch (e) {
        const msg = { "auth/invalid-credential": "Email o password sbagliate.", "auth/email-already-in-use": "Questo account esiste già: tocca Accedi.",
          "auth/weak-password": "La password deve avere almeno 6 caratteri.", "auth/invalid-email": "Email non valida.",
          "auth/network-request-failed": "Serve internet per accedere." }[e.code] || e.code;
        alert(msg);
      }
    };
    $("#accedi").onclick = () => prova(A.signInWithEmailAndPassword);
    $("#crea").onclick = () => prova(A.createUserWithEmailAndPassword);
    $("#dimenticata").onclick = async () => {
      const email = $("#sEmail").value.trim();
      if (!email) return alert("Scrivi prima la tua email.");
      try { await A.sendPasswordResetEmail(auth, email); alert("Ti ho mandato un'email per scegliere una nuova password."); }
      catch (e) { alert(e.code); }
    };
  }
}

avvia().catch(e => stato(`<div class="kv"><span style="color:var(--red)">Sincronizzazione non disponibile: ${esc(e.message)}</span></div>`));
