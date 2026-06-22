// EL Parking — branded Firebase Auth action handler (password reset / email verify).
// Set as the "action URL" in Firebase Console → Authentication → Templates so the
// links in those emails point to https://elpark.cz/auth-action.html instead of the
// generic firebaseapp.com page.
import { initializeApp } from "https://www.gstatic.com/firebasejs/11.7.1/firebase-app.js";
import {
  getAuth,
  verifyPasswordResetCode,
  confirmPasswordReset,
  applyActionCode,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-auth.js";
import { firebaseConfig } from "./firebase-config.js";

const content = document.getElementById("content");
const params = new URLSearchParams(window.location.search);
const mode = params.get("mode");
const oobCode = params.get("oobCode");

const APP_URL = "https://elpark.cz/";
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const appLink = `<a class="applink" href="${APP_URL}">Open EL Parking →</a>`;

let auth;
try {
  auth = getAuth(initializeApp(firebaseConfig));
} catch (e) {
  content.innerHTML = `<h2>Something went wrong</h2><p class="muted">Couldn't start. Please try again later.</p>`;
}

function show(html) { content.innerHTML = html; }

async function handleResetPassword() {
  let email;
  try {
    email = await verifyPasswordResetCode(auth, oobCode);
  } catch (e) {
    return show(`<h2>Link expired</h2><p class="muted">This password reset link is invalid or has expired. Request a new one from the app.</p>${appLink}`);
  }
  show(`
    <h2>Set a new password</h2>
    <p class="muted">for ${esc(email)}</p>
    <form id="f">
      <label for="pw">New password</label>
      <input id="pw" type="password" autocomplete="new-password" minlength="6" required />
      <label for="pw2">Confirm password</label>
      <input id="pw2" type="password" autocomplete="new-password" minlength="6" required />
      <button id="b" type="submit">Reset password</button>
      <p class="error" id="err"></p>
    </form>`);
  const f = document.getElementById("f");
  const err = document.getElementById("err");
  f.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const pw = document.getElementById("pw").value;
    const pw2 = document.getElementById("pw2").value;
    err.textContent = "";
    if (pw.length < 6) { err.textContent = "Password must be at least 6 characters."; return; }
    if (pw !== pw2) { err.textContent = "Passwords don't match."; return; }
    const btn = document.getElementById("b");
    btn.disabled = true;
    try {
      await confirmPasswordReset(auth, oobCode, pw);
      show(`<h2 class="ok">Password updated</h2><p class="muted">You can now sign in to EL Parking with your new password.</p>${appLink}`);
    } catch (e) {
      btn.disabled = false;
      err.textContent = "Couldn't reset the password — the link may have expired. Request a new one.";
    }
  });
}

async function handleVerifyEmail() {
  try {
    await applyActionCode(auth, oobCode);
    show(`<h2 class="ok">Email verified</h2><p class="muted">Your email is confirmed. You can sign in to EL Parking.</p>${appLink}`);
  } catch (e) {
    show(`<h2>Link expired</h2><p class="muted">This verification link is invalid or has expired.</p>${appLink}`);
  }
}

if (!auth) {
  /* init error already shown */
} else if (!mode || !oobCode) {
  show(`<h2>EL Parking</h2><p class="muted">This page handles account links from EL Parking emails.</p>${appLink}`);
} else if (mode === "resetPassword") {
  handleResetPassword();
} else if (mode === "verifyEmail" || mode === "recoverEmail") {
  handleVerifyEmail();
} else {
  show(`<h2>Unsupported action</h2><p class="muted">This link type isn't supported here.</p>${appLink}`);
}
