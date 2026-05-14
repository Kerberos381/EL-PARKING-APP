const response = await fetch("./app.js", { cache: "no-store" });
if (!response.ok) {
  throw new Error(`Failed to load app.js (${response.status})`);
}

let source = await response.text();

// Hotfix for TDZ: remove early boot() call and run it at the end of module body.
source = source.replace(/\nboot\(\);\n/, "\n");
source = `${source}\n\nboot();\n`;

const blob = new Blob([source], { type: "text/javascript" });
const moduleUrl = URL.createObjectURL(blob);
try {
  await import(moduleUrl);
} finally {
  URL.revokeObjectURL(moduleUrl);
}
