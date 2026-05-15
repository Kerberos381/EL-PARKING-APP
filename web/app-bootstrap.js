const authForm = document.getElementById("loginForm");
const authError = document.getElementById("authError");
const KEEP_SIGNED_IN_KEY = "el_parking_keep_signed_in";

// Prevent full-page reload even if app module fails to initialize.
authForm?.addEventListener("submit", (event) => {
  event.preventDefault();
});

function injectRememberMeControl() {
  const loginButton = document.getElementById("loginButton");
  if (!loginButton || document.getElementById("rememberMeInput")) return;

  const label = document.createElement("label");
  label.className = "field inline remember-me";
  label.innerHTML = `<input id="rememberMeInput" type="checkbox" /><span>Keep me signed in</span>`;
  loginButton.insertAdjacentElement("beforebegin", label);

  const checkbox = document.getElementById("rememberMeInput");
  checkbox.checked = localStorage.getItem(KEEP_SIGNED_IN_KEY) !== "false";
  checkbox.addEventListener("change", () => {
    localStorage.setItem(KEEP_SIGNED_IN_KEY, checkbox.checked ? "true" : "false");
  });
}

function injectResponsiveFixes() {
  if (document.getElementById("elProductionBootstrapFixes")) return;
  const style = document.createElement("style");
  style.id = "elProductionBootstrapFixes";
  style.textContent = `
    html, body { max-width: 100%; overflow-x: hidden; }
    .app, .tabpanel, .card { min-width: 0; max-width: 100%; overflow-x: hidden; box-sizing: border-box; }
    .section-head { display:flex; align-items:center; justify-content:space-between; gap:16px; flex-wrap:nowrap; }
    .section-head h3 { margin:0; min-width:0; }
    .section-head .btn { margin-left:auto; flex:0 0 auto; }
    .remember-me { display:flex; align-items:center; gap:10px; flex-direction:row; color:#6b7078; font-weight:800; }
    .remember-me input { width:22px; height:22px; accent-color:#34c759; }
    .day-pills { display:flex; gap:12px; overflow-x:auto; overflow-y:hidden; scroll-snap-type:x proximity; -webkit-overflow-scrolling:touch; padding:4px 2px 10px; margin-inline:-2px; }
    .day-pill { flex:0 0 118px; scroll-snap-align:start; }
    .spot-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(150px, 1fr)); gap:14px; }
    .spot-tile { min-width:0; cursor:pointer; }
    .spot-tile.free { background:#f6fff9; border-color:#bfeccc; }
    .spot-tile.selected, .spot-tile.free.selected { background:#eafbf0; border-color:#34c759; box-shadow:0 0 0 4px rgba(52,199,89,.16), 0 18px 34px rgba(52,199,89,.18); }
    .spot-tile.booked { background:#fff3f3; border-color:#ffb7b7; color:#8a1f1f; }
    .spot-tile.blocked { background:#f1f2f4; color:#8a8f98; }
    .field input, .field select { min-width:0; width:100%; box-sizing:border-box; }
    .row { min-width:0; }
    .booking-time-grid { display:grid; grid-template-columns:1.2fr 1fr 1fr; gap:14px; }
    .hidden-native-select { position:absolute; inline-size:1px; block-size:1px; opacity:0; pointer-events:none; }
    .booking-row { gap:14px; }
    .booking-row-actions { display:flex; gap:10px; align-items:center; justify-content:flex-end; flex-wrap:wrap; }
    .modal-card { width:min(560px, calc(100vw - 40px)); }
    @media (max-width: 760px) {
      body { padding: 28px 12px 96px; }
      .app { width:100%; }
      .topbar { display:grid; grid-template-columns:1fr auto; align-items:start; gap:12px; }
      .topbar h1 { font-size:clamp(52px, 15vw, 84px); line-height:.9; max-width:100%; overflow-wrap:anywhere; }
      .topbar .btn { padding:18px 22px; white-space:nowrap; }
      .card { border-radius:28px; padding:24px; }
      .stats { grid-template-columns:repeat(3, minmax(0, 1fr)); gap:10px; }
      .stats div { min-width:0; padding:18px 8px; }
      .day-pill { flex-basis:112px; min-height:116px; }
      .spot-grid { grid-template-columns:repeat(2, minmax(0, 1fr)); gap:12px; }
      .spot-tile { min-height:154px; padding:18px; }
      .spot-tile strong { font-size:clamp(42px, 12vw, 64px); }
      .booking-time-grid, #bookForm > .row { display:grid; grid-template-columns:1fr; gap:12px; }
      .tabbar { position:fixed; left:12px; right:12px; bottom:18px; z-index:50; display:grid; grid-template-columns:repeat(5, minmax(0, 1fr)); gap:0; padding:8px; border-radius:30px; background:rgba(255,255,255,.92); backdrop-filter:blur(22px); box-shadow:0 10px 30px rgba(0,0,0,.14); }
      .tab { min-width:0; padding:16px 6px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
      .btn { min-height:54px; }
      .section-head .btn { padding:14px 18px; min-height:48px; }
    }
    @media (max-width: 390px) {
      body { padding-inline:10px; }
      .card { padding:20px; }
      .spot-grid { grid-template-columns:repeat(2, minmax(0, 1fr)); gap:10px; }
      .spot-tile { min-height:138px; padding:14px; }
      .tab { font-size:14px; }
    }
  `;
  document.head.appendChild(style);
}

function patchImport(source, moduleUrl, names) {
  return source.replace(new RegExp(`import \\{([\\s\\S]*?)\\} from "${moduleUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}";`), (match, body) => {
    const existing = new Set(body.split(",").map((part) => part.trim()).filter(Boolean));
    names.forEach((name) => existing.add(name));
    return `import {\n  ${Array.from(existing).join(",\n  ")},\n} from "${moduleUrl}";`;
  });
}

try {
  injectRememberMeControl();
  injectResponsiveFixes();

  const response = await fetch("./app.js", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Failed to load app.js (${response.status})`);
  }

  let source = await response.text();

  const firebaseConfigUrl = new URL("./firebase-config.js", import.meta.url).href;
  source = source.replace(
    /from\s+["']\.\/firebase-config\.js["']/,
    `from "${firebaseConfigUrl}"`
  );

  source = patchImport(source, "https://www.gstatic.com/firebasejs/11.7.1/firebase-auth.js", [
    "browserLocalPersistence",
    "browserSessionPersistence",
  ]);
  source = patchImport(source, "https://www.gstatic.com/firebasejs/11.7.1/firebase-firestore.js", [
    "getDocs",
    "getDocsFromServer",
    "limit",
    "query",
    "where",
  ]);

  source = source.replace(
    /await setPersistence\(auth, browserSessionPersistence\);/,
    `const keepSignedIn = localStorage.getItem("${KEEP_SIGNED_IN_KEY}") !== "false";
      await setPersistence(auth, keepSignedIn ? browserLocalPersistence : browserSessionPersistence);`
  );

  source = source.replace(
    /ui\.authError\.textContent = "";\n\s*ui\.passwordInput\.value = "";/,
    'if (!window.__elAuthErrorSticky) ui.authError.textContent = "";\n    window.__elAuthErrorSticky = false;\n    ui.passwordInput.value = "";'
  );

  source = source.replace(
    /const profileSnap = await getDoc\(doc\(db, "users", user\.uid\)\);\n\s*if \(!profileSnap\.exists\(\)\) \{\n\s*await signOut\(auth\);\n\s*ui\.authError\.textContent = "User profile not found\.";\n\s*return;\n\s*\}\n\n\s*state\.profile = parseUser\(profileSnap\.data\(\)\);/,
    `const profileSnap = await getDoc(doc(db, "users", user.uid));
  let profileData = null;
  if (profileSnap.exists()) {
    profileData = profileSnap.data();
  } else {
    profileData = await lookupProfileByEmail(user.email);
  }

  if (!profileData) {
    window.__elAuthErrorSticky = true;
    await signOut(auth);
    ui.authError.textContent = "User profile not found in Firestore (UID/email mismatch).";
    return;
  }

  state.profile = parseUser(profileData);`
  );

  source = source.replace(
    /function parseUser\(data\) \{/,
    `async function lookupProfileByEmail(email) {
  const normalized = String(email || "").trim().toLowerCase();
  if (!normalized) return null;
  const q = query(collection(db, "users"), where("email", "==", normalized), limit(1));
  const snap = await getDocs(q);
  if (snap.empty) return null;
  return snap.docs[0].data();
}

function parseUser(data) {`
  );

  source = source.replace(/\nboot\(\);\n/, "\n");
  source = `${source}\n\nboot();\n`;

  const blob = new Blob([source], { type: "text/javascript" });
  const moduleUrl = URL.createObjectURL(blob);
  try {
    await import(moduleUrl);
  } finally {
    URL.revokeObjectURL(moduleUrl);
  }
} catch (error) {
  console.error("Bootstrap failure:", error);
  if (authError) {
    authError.textContent = `Initialization failed: ${error?.message || String(error)}`;
  }
}
