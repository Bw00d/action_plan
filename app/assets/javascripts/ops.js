$(document).on("turbolinks:load", function () {
  // All handlers are bound with a `.ops` namespace and off()'d first so
  // repeat Turbolinks visits don't stack duplicate listeners. Without
  // this, each keystroke fires PATCH once per prior visit, and the
  // first insert wins the unique index while the rest fail with a
  // 500 (RecordNotUnique).
  $(document).off(".ops");

  // Div/group picker: navigate to the same URL with the picked org_unit_id.
  $(document).on("change.ops", "#ops-org-unit-picker", function () {
    var $picker = $(this);
    var base    = $picker.data("base-url");
    var id      = $picker.val();
    var sep     = base.indexOf("?") === -1 ? "?" : "&";
    window.location = base + sep + "org_unit_id=" + id;
  });

  // Add a new Kind/Type row to a 215 table. Row is client-side only until
  // a Req value is entered — that triggers the existing PATCH handler
  // which persists the ops_215_line and the row survives a refresh.
  function addKindTypeRow($table, position) {
    position = (position || "").trim();
    if (!position) return;

    var $tbody = $table.find("tbody");
    // Duplicate protection — if the position already has a row, focus its
    // first Req input instead of adding a duplicate.
    var existing = $tbody.find("tr").filter(function () {
      return $(this).find("td.ops-215-kind").first().text().trim().toLowerCase() === position.toLowerCase();
    });
    if (existing.length) {
      existing.find(".ops-215-req-input").first().focus();
      return;
    }

    // Drop the "no resources assigned" placeholder if present.
    $tbody.find("tr.ops-215-empty-row").remove();

    // Build cells from the header day columns so day count matches.
    var $dayHeaders = $table.find("thead tr").first().find("th.ops-215-day");
    var cells = "";
    $dayHeaders.each(function () {
      // Header text like "Mon 9/8" — recover the ISO day from the
      // corresponding input in an existing row if present, otherwise
      // fall back to a data-day derived from the header text via the
      // table's known day range. Simpler: pull from an existing row.
    });

    // Get the ISO days from an existing row's inputs. If the table was
    // empty, fall back to reading them from the .ops-215-add-row's own
    // hidden day markers — we'll seed those from the first existing input
    // in any table on the page, but that's fragile. Instead, ship the
    // days as a data attribute on the table for reliability.
    var days = ($table.data("days") || "").toString().split(",");
    if (!days.length || !days[0]) {
      // Fallback: read from any existing row's Req inputs.
      var seen = {};
      $tbody.find(".ops-215-req-input").each(function () {
        var d = $(this).data("day");
        if (d && !seen[d]) { seen[d] = true; days.push(d); }
      });
    }

    var row = '<tr>';
    row += '<td class="ops-215-kind">' + $("<div>").text(position).html() + '</td>';
    days.forEach(function (day) {
      row += '<td class="ops-215-have">0</td>';
      row += '<td class="ops-215-req">' +
             '<input type="number" min="0" value="" class="ops-215-req-input" ' +
             'data-day="' + day + '" data-position="' + $("<div>").text(position).html() + '">' +
             '</td>';
      row += '<td class="ops-215-need"></td>';
    });
    row += '</tr>';

    $tbody.append(row);
    // Focus the first Req cell so the user can start typing immediately.
    $tbody.find("tr").last().find(".ops-215-req-input").first().focus();
  }

  $(document).on("click.ops", ".ops-print-btn", function () {
    window.print();
  });

  $(document).on("click.ops", ".ops-215-add-btn", function () {
    var $btn   = $(this);
    var $table = $btn.closest(".ops-215-table");
    var $input = $btn.closest("td").find(".ops-215-add-input");
    addKindTypeRow($table, $input.val());
    $input.val("");
  });

  $(document).on("keydown.ops", ".ops-215-add-input", function (e) {
    if (e.key !== "Enter") return;
    e.preventDefault();
    var $input = $(this);
    var $table = $input.closest(".ops-215-table");
    addKindTypeRow($table, $input.val());
    $input.val("");
  });

  // Auto-save Req cell on blur or Enter.
  $(document).on("change.ops", ".ops-215-req-input", function () {
    var $input = $(this);
    var $table = $input.closest(".ops-215-table");
    var url    = $table.data("update-url");
    // Send raw string so the server can distinguish "" (unset → delete)
    // from "0" (explicit zero → keep, drives a negative Need).
    $.ajax({
      url: url,
      method: "PATCH",
      data: {
        org_unit_id: $table.data("org-unit-id"),
        day:         $input.data("day"),
        position:    $input.data("position"),
        req:         $input.val()
      }
    }).done(function () {
      // Recompute Need in-place so the user sees it update without a reload.
      var $row   = $input.closest("tr");
      var $cells = $row.find(".ops-215-req");
      $cells.each(function (idx) {
        var $r   = $(this).find(".ops-215-req-input");
        var $h   = $(this).prev(".ops-215-have");
        var $n   = $(this).next(".ops-215-need");
        var raw  = $r.val();
        if (raw === "" || raw == null) {
          $n.text("");
        } else {
          var need = (parseInt(raw, 10) || 0) - (parseInt($h.text(), 10) || 0);
          $n.text(need === 0 ? "" : need);
        }
      });
    }).fail(function (xhr) {
      var body = xhr.responseText || "";
      console.error("update_line failed", xhr.status, body);
      alert(
        "Could not save Req value (" + xhr.status + ").\n\n" +
        (body.length > 400 ? body.slice(0, 400) + "…" : body)
      );
    });
  });
});
