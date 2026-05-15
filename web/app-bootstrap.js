const authForm = document.getElementById("loginForm");
const authError = document.getElementById("authError");

// Legacy loader kept for browsers that cached an older index.html.
// The current index.html loads app.js directly. This file must not rewrite imports,
// because current app.js already imports browserLocalPersistence and other helpers.
authForm?.addEventListener("submit", (event) => {
  event.preventDefault();
});

try {
  await import(`./app.js?v=${Date.now()}`);
} catch (error) {
  console.error("Bootstrap failure:", error);
  if (authError) {
    authError.textContent = `Initialization failed: ${error?.message || String(error)}`;
  }
}
