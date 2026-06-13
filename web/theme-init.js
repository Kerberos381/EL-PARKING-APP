(function () {
  // ── Early apply, before first paint (avoids flash of wrong theme) ──
  var root = document.documentElement;
  var theme = localStorage.getItem("el-parking-theme");
  var sysDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  if (theme === "dark" || (theme !== "light" && sysDark)) root.classList.add("dark-mode");
  if (localStorage.getItem("el-parking-palette") === "calm") root.classList.add("palette-calm");
  if (localStorage.getItem("el-parking-density") === "compact") root.classList.add("density-compact");

  // ── Wire the Settings appearance controls once the DOM is ready ──
  // (Inline scripts are blocked by the page CSP, so all wiring lives here.)
  function wire() {
    var themeBtn = document.getElementById("themeToggleBtn");
    if (themeBtn) {
      themeBtn.addEventListener("click", function () {
        var isDark = root.classList.toggle("dark-mode");
        localStorage.setItem("el-parking-theme", isDark ? "dark" : "light");
      });
    }

    function bindSeg(segId, attr, cls, storageKey, activeValue) {
      var seg = document.getElementById(segId);
      if (!seg) return;
      var buttons = seg.querySelectorAll("[data-" + attr + "]");
      function sync(value) {
        for (var i = 0; i < buttons.length; i++) {
          buttons[i].classList.toggle(
            "active",
            buttons[i].getAttribute("data-" + attr) === value
          );
        }
        root.classList.toggle(cls, value === activeValue);
      }
      for (var i = 0; i < buttons.length; i++) {
        (function (btn) {
          btn.addEventListener("click", function () {
            var value = btn.getAttribute("data-" + attr);
            localStorage.setItem(storageKey, value);
            sync(value);
          });
        })(buttons[i]);
      }
      sync(localStorage.getItem(storageKey) || "default");
    }

    bindSeg("paletteSeg", "palette", "palette-calm", "el-parking-palette", "calm");
    bindSeg("densitySeg", "density", "density-compact", "el-parking-density", "compact");
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", wire);
  } else {
    wire();
  }
})();
