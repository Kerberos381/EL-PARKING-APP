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

  // TDZ hotfix: remove the first eager boot() invocation regardless of whitespace/newlines.
  source = source.replace(/\bboot\(\);\s*/, "");

  // Ensure boot() runs only after declarations are initialized.
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
