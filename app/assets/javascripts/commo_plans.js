// ICS-205 channel row copy / paste.
//
// Trigger: user drag-selects across 2+ cells in a single row → floating
// "COPY ROW" chip appears near the selection. Click → row's field values
// (minus zone + ch_num) get stashed in an in-memory buffer. Once
// something's copied, hovering any OTHER row reveals a "PASTE" chip
// pinned to the row's right edge; click PATCHes the target row and
// updates the DOM. Overwriting a row with existing content prompts.
$(document).on("turbolinks:load", function () {

  // Fields that get copied. Zone + Ch # are per-row unique so they're
  // deliberately excluded per user preference.
  var COPY_FIELDS = [
    "channel_name", "function",
    "rx_freq", "rx_tone", "tx_freq", "tx_tone",
    "assignment", "mode", "remarks"
  ];

  var copyBuffer = null;         // { itemId, sourceLabel, values: { field: value } }
  var $copyChip  = null;
  var $pasteChip = null;
  var $tableRoot = $("#commo-plan");

  if (!$tableRoot.length) return;

  // ── Helpers ─────────────────────────────────────────────────────
  function cellValue($tr, field) {
    // best_in_place renders the current value as the .best_in_place
    // span's text. Fall back to plain td text for safety.
    var $cell = $tr.find('td[data-field="' + field + '"]');
    if (!$cell.length) return "";
    var $bip = $cell.find(".best_in_place").first();
    return ($bip.length ? $bip.text() : $cell.text()).trim();
  }

  function setCellValue($tr, field, value) {
    var $cell = $tr.find('td[data-field="' + field + '"]');
    if (!$cell.length) return;
    var $bip = $cell.find(".best_in_place").first();
    if ($bip.length) {
      $bip.text(value || "");
    } else {
      $cell.text(value || "");
    }
  }

  function rowHasContent($tr) {
    return COPY_FIELDS.some(function (f) { return cellValue($tr, f).length > 0; });
  }

  function rowLabel($tr) {
    var ch = cellValue($tr, "ch_num");
    return ch ? "Ch " + ch : "Row " + ($tableRoot.find("tr.radio-channel").index($tr) + 1);
  }

  // ── Floating chip creation ──────────────────────────────────────
  function removeCopyChip() {
    if ($copyChip) { $copyChip.remove(); $copyChip = null; }
  }
  function removePasteChip() {
    if ($pasteChip) { $pasteChip.remove(); $pasteChip = null; }
  }

  function showCopyChip($tr, x, y) {
    removeCopyChip();
    $copyChip = $('<button type="button" class="cp-chip cp-chip-copy">COPY ROW</button>')
      .css({ left: x + "px", top: y + "px" })
      .appendTo(document.body);
    $copyChip.on("click", function (e) {
      e.stopPropagation();
      captureRow($tr);
      window.getSelection().removeAllRanges();
    });
  }

  function showPasteChip($tr) {
    removePasteChip();
    if (!copyBuffer) return;
    if (String($tr.data("item-id")) === String(copyBuffer.itemId)) return; // skip source row
    var rect = $tr[0].getBoundingClientRect();
    var top  = rect.top + window.scrollY + (rect.height / 2) - 12;
    var left = rect.right + window.scrollX - 138;
    $pasteChip = $('<button type="button" class="cp-chip cp-chip-paste">' +
                   'PASTE from ' + escapeHtml(copyBuffer.sourceLabel) + '</button>')
      .css({ left: left + "px", top: top + "px" })
      .appendTo(document.body);
    $pasteChip.on("click", function (e) {
      e.stopPropagation();
      applyPaste($tr);
    });
  }

  function escapeHtml(s) {
    return $("<div>").text(s || "").html();
  }

  // ── Selection detection ────────────────────────────────────────
  // On mouseup, check if the current selection spans 2+ cells in the
  // same row. Uses a timeout so the selection is settled before we read.
  $(document).off("mouseup.cpCopy").on("mouseup.cpCopy", function (e) {
    // Skip if the click was inside a chip — otherwise clicking the chip
    // clears its own selection detection.
    if ($(e.target).closest(".cp-chip").length) return;
    setTimeout(function () {
      var sel = window.getSelection();
      if (!sel || sel.rangeCount === 0 || sel.isCollapsed) { removeCopyChip(); return; }
      var range = sel.getRangeAt(0);
      var $start = $(range.startContainer).closest("td[data-field]");
      var $end   = $(range.endContainer).closest("td[data-field]");
      if (!$start.length || !$end.length) { removeCopyChip(); return; }
      var $trStart = $start.closest("tr.radio-channel");
      var $trEnd   = $end.closest("tr.radio-channel");
      if (!$trStart.length || $trStart[0] !== $trEnd[0]) { removeCopyChip(); return; }
      if ($start[0] === $end[0]) { removeCopyChip(); return; } // same cell only
      var rect = range.getBoundingClientRect();
      var x = rect.right + window.scrollX + 6;
      var y = rect.top + window.scrollY - 4;
      showCopyChip($trStart, x, y);
    }, 0);
  });

  // Clicking outside the copy chip dismisses it.
  $(document).off("mousedown.cpCopyDismiss").on("mousedown.cpCopyDismiss", function (e) {
    if ($copyChip && !$(e.target).closest(".cp-chip-copy").length) removeCopyChip();
  });

  // ── Capture (copy) ─────────────────────────────────────────────
  function captureRow($tr) {
    var values = {};
    COPY_FIELDS.forEach(function (f) { values[f] = cellValue($tr, f); });
    copyBuffer = {
      itemId:      $tr.data("item-id"),
      sourceLabel: rowLabel($tr),
      values:      values
    };
    removeCopyChip();
    flashToast("Row copied — hover another row to paste");
  }

  // ── Paste chip on hover (after a copy exists) ──────────────────
  $tableRoot.off("mouseenter.cpPaste").on("mouseenter.cpPaste", "tr.radio-channel", function () {
    if (!copyBuffer) return;
    showPasteChip($(this));
  });
  $tableRoot.off("mouseleave.cpPaste").on("mouseleave.cpPaste", "tr.radio-channel", function () {
    if ($pasteChip && $pasteChip.is(":hover")) return;
    removePasteChip();
  });
  $(document).off("mouseleave.cpPasteChip").on("mouseleave.cpPasteChip", ".cp-chip-paste", function () {
    removePasteChip();
  });

  // ── Apply (paste) ──────────────────────────────────────────────
  function applyPaste($tr) {
    if (!copyBuffer) return;
    if (rowHasContent($tr)) {
      if (!confirm("Overwrite " + rowLabel($tr) + "? Existing values will be replaced.")) {
        return;
      }
    }
    var itemId  = $tr.data("item-id");
    var payload = { commo_item: {} };
    COPY_FIELDS.forEach(function (f) { payload.commo_item[f] = copyBuffer.values[f] || ""; });

    $.ajax({
      url:      "/commo_items/" + itemId,
      type:     "PATCH",
      data:     payload,
      dataType: "json",
      headers:  { "X-CSRF-Token": $('meta[name="csrf-token"]').attr("content") }
    })
      .done(function () {
        COPY_FIELDS.forEach(function (f) { setCellValue($tr, f, copyBuffer.values[f]); });
        removePasteChip();
        flashToast("Pasted into " + rowLabel($tr));
      })
      .fail(function (xhr) {
        alert("Paste failed (" + xhr.status + "). " + (xhr.responseText || "").slice(0, 200));
      });
  }

  // ── Tiny toast ─────────────────────────────────────────────────
  var toastTimer = null;
  function flashToast(msg) {
    var $t = $("#cp-toast");
    if (!$t.length) {
      $t = $('<div id="cp-toast" class="cp-toast"></div>').appendTo(document.body);
    }
    $t.text(msg).addClass("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { $t.removeClass("is-visible"); }, 1800);
  }

  // Legacy blank-row hover behavior (preserved from prior version).
  $(".blank-row").hover(
    function () { $(".commo-item-form").first().show(); },
    function () { $(".commo-item-form").first().hide(); }
  );
});
