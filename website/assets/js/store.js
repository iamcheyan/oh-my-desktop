/* Store filtering + search. Progressive enhancement over static HTML. */
(function () {
  var grid = document.getElementById("store-grid");
  if (!grid) return;
  var cards = Array.prototype.slice.call(grid.querySelectorAll(".ext-card"));
  var search = document.getElementById("store-search");
  var buttons = Array.prototype.slice.call(document.querySelectorAll(".filter-btn"));
  var empty = document.getElementById("store-empty");
  var filter = "all";

  function apply() {
    var q = search ? search.value.trim().toLowerCase() : "";
    var visible = 0;
    cards.forEach(function (card) {
      var okCat = filter === "all" || card.dataset.category === filter;
      var okText = !q || (card.dataset.name || "").indexOf(q) !== -1;
      var show = okCat && okText;
      card.classList.toggle("hidden", !show);
      if (show) visible++;
    });
    if (empty) empty.classList.toggle("hidden", visible !== 0);
  }

  buttons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      buttons.forEach(function (b) { b.classList.remove("active"); });
      btn.classList.add("active");
      filter = btn.dataset.filter;
      apply();
    });
  });

  // Whole-card click navigation (cards are divs to avoid nested anchors).
  document.querySelectorAll(".ext-card[data-href]").forEach(function (card) {
    card.addEventListener("click", function (ev) {
      if (ev.target.closest("a")) return;
      window.location.href = card.dataset.href;
    });
  });
  if (search) search.addEventListener("input", apply);
})();
