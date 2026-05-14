const authForm = document.getElementById("loginForm");
const authError = document.getElementById("authError");

// Prevent full-page reload even if app module fails to initialize.
authForm?.addEventListener("submit", (event) => {
  event.preventDefault();
});

try {
  const response = await fetch("./app.js", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Failed to load app.js (${response.status})`);
  }

  let source = await response.text();

  // Fix relative import when running from blob URL.
  const firebaseConfigUrl = new URL("./firebase-config.js", import.meta.url).href;
  source = source.replace(
    /from\s+["']\.\/firebase-config\.js["']/,
    `from "${firebaseConfigUrl}"`
  );

  // Extend Firestore import for email fallback query helpers.
  source = source.replace(
    /updateDoc,\s*\n\} from "https:\/\/www\.gstatic\.com\/firebasejs\/11\.7\.1\/firebase-firestore\.js";/,
    "updateDoc,\n  getDocs,\n  limit,\n  query,\n  where,\n} from \"https://www.gstatic.com/firebasejs/11.7.1/firebase-firestore.js\";"
  );

  // Keep auth error visible across forced signOut in auth-state callback.
  source = source.replace(
    /ui\.authError\.textContent = "";\n\s*ui\.passwordInput\.value = "";/,
    'if (!window.__elAuthErrorSticky) ui.authError.textContent = "";\n    window.__elAuthErrorSticky = false;\n    ui.passwordInput.value = "";'
  );

  // Fallback profile lookup by email when users/{uid} doc is missing.
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

  // Inject helper before parseUser()
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

  // TDZ hotfix: remove first eager boot() invocation and run at end.
  source = source.replace(/\bboot\(\);\s*/, "");
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
