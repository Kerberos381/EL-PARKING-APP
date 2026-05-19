(function () {
  var pref = localStorage.getItem("el-parking-theme");
  var sys = window.matchMedia("(prefers-color-scheme: dark)").matches;
  if (pref === "dark" || (pref !== "light" && sys)) {
    document.documentElement.classList.add("dark-mode");
  }
})();
