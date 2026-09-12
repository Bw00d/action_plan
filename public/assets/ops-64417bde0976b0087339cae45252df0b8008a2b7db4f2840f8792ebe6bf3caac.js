$(document).on("turbolinks:load", function () {
  // Div/group picker: navigate to the same URL with the picked org_unit_id.
  $(document).on("change", "#ops-org-unit-picker", function () {
    var $picker = $(this);
    var base    = $picker.data("base-url");
    var id      = $picker.val();
    var sep     = base.indexOf("?") === -1 ? "?" : "&";
    window.location = base + sep + "org_unit_id=" + id;
  });

  // Auto-save Req cell on blur or Enter.
  $(document).on("change", ".ops-215-req-input", function () {
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
