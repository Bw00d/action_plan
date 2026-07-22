// Canvas-based cover editor.
//   Phase 2: drag blocks around the canvas and persist their new x/y (as
//            % of canvas) on drop.
//   Phase 3: show alignment guides at 16.5% / 50% / 83.5% during drag;
//            snap the block's center-x to the closest guide on drop.
//   Phase 4: resize blocks via jQuery UI handles; persist new center +
//            width/height on stop.
//   Phase 5: click a block to select it; a style panel below the canvas
//            reflects that block's current styles. Clicking a style
//            button updates the block's DOM class and PATCHes the field.
$(document).on("turbolinks:load", function () {
  var $canvas = $("#cover-canvas");
  if (!$canvas.length) return;

  var SNAP_THRESHOLD_PX = 8;
  var GRID_PX = 5;   // snap drag/resize to a 10px grid for uniformity
  var $guides = $canvas.find(".cover-guide");

  function csrfToken() {
    return $('meta[name="csrf-token"]').attr("content");
  }

  function saveBlockRect(id, data) {
    return $.ajax({
      url: "/blocks/" + id,
      method: "PATCH",
      data: { block: data },
      headers: { "X-CSRF-Token": csrfToken() },
      dataType: "json",
    });
  }

  // Guide-x values are stored as percentages on data attributes; convert
  // them to pixel positions relative to the canvas at call time so any
  // canvas resize (viewport width change) picks up automatically.
  function guidePxPositions(canvasW) {
    return $guides.map(function () {
      return {
        $el: $(this),
        pct: parseFloat($(this).data("guide-x")),
        px: (parseFloat($(this).data("guide-x")) / 100) * canvasW,
      };
    }).get();
  }

  // Return the closest guide within SNAP_THRESHOLD_PX of centerX_px, or
  // null if none qualifies.
  function closestGuide(centerX_px, canvasW) {
    var closest = null;
    var closestDist = SNAP_THRESHOLD_PX + 1;
    guidePxPositions(canvasW).forEach(function (g) {
      var d = Math.abs(centerX_px - g.px);
      if (d < closestDist) {
        closestDist = d;
        closest = g;
      }
    });
    return closest;
  }

  function initDrag() {
    $canvas.find(".cover-block").each(function () {
      var $block = $(this);
      if ($block.data("uiDraggable")) return;

      $block.draggable({
        // Don't start a drag when the user grabs a resize handle.
        cancel: ".ui-resizable-handle",
        // Snap movement to a grid; snap-to-guide logic in `drag` below
        // can still override the horizontal position when close to a
        // guide (guides take priority over the grid).
        grid: [GRID_PX, GRID_PX],

        // Compute containment at drag start so it accounts for this
        // block's current pixel size. We allow the block to overflow
        // horizontally by half its width in either direction so the
        // block's CENTER can reach any x in [0%, 100%] of the canvas
        // (that's what makes the 16.5% / 83.5% snap guides reachable
        // even when the block is wider than a third). Vertically we
        // keep the block fully inside the canvas.
        start: function () {
          var canvasOff = $canvas.offset();
          var canvasW = $canvas.width();
          var canvasH = $canvas.height();
          var blockW = $block.outerWidth();
          var blockH = $block.outerHeight();
          $block.draggable("option", "containment", [
            canvasOff.left - blockW / 2,               // left bound
            canvasOff.top,                              // top bound
            canvasOff.left + canvasW - blockW / 2,     // right bound
            canvasOff.top + canvasH - blockH,          // bottom bound
          ]);
        },

        // Highlight the closest guide (if any) throughout the drag.
        drag: function () {
          var canvasW = $canvas.width();
          var centerX_px = $block.position().left + $block.outerWidth() / 2;
          var active = closestGuide(centerX_px, canvasW);
          $guides.removeClass("is-active");
          if (active) active.$el.addClass("is-active");
        },

        // On drop: if a guide is active, snap the block's center-x to it.
        // Then rewrite the inline style back to % and persist.
        stop: function () {
          var canvasW = $canvas.width();
          var canvasH = $canvas.height();
          var centerX_px = $block.position().left + $block.outerWidth() / 2;
          var centerY_px = $block.position().top + $block.outerHeight() / 2;

          var active = closestGuide(centerX_px, canvasW);
          if (active) centerX_px = active.px;
          $guides.removeClass("is-active");

          var widthPct = ($block.outerWidth() / canvasW) * 100;
          var heightPct = ($block.outerHeight() / canvasH) * 100;
          var xPct = (centerX_px / canvasW) * 100;
          var yPct = (centerY_px / canvasH) * 100;

          $block.css({
            left: xPct - widthPct / 2 + "%",
            top: yPct - heightPct / 2 + "%",
          });

          saveBlockRect($block.data("block-id"), {
            x: xPct.toFixed(3),
            y: yPct.toFixed(3),
          });
        },
      });
    });
  }

  function initResize() {
    $canvas.find(".cover-block").each(function () {
      var $block = $(this);
      if ($block.data("uiResizable")) return;

      // Text blocks aren't resizable — their size comes from the H1–H4
      // buttons or the pixel input in the style panel. Only image
      // blocks get corner handles.
      if (!$block.hasClass("is-image")) return;
      $block.resizable({
        handles: "ne, nw, se, sw",
        minWidth: 24,
        minHeight: 20,
        aspectRatio: true,
        grid: [GRID_PX, GRID_PX],   // resize in 10px steps for uniformity
        // On stop: recompute center + w/h as % of canvas and persist.
        // Resize handles that aren't the SE corner also shift the block's
        // top-left, so we always send x/y along with width/height.
        stop: function () {
          var canvasW = $canvas.width();
          var canvasH = $canvas.height();
          var centerX_px = $block.position().left + $block.outerWidth() / 2;
          var centerY_px = $block.position().top + $block.outerHeight() / 2;
          var widthPct = ($block.outerWidth() / canvasW) * 100;
          var heightPct = ($block.outerHeight() / canvasH) * 100;
          var xPct = (centerX_px / canvasW) * 100;
          var yPct = (centerY_px / canvasH) * 100;

          $block.css({
            left: xPct - widthPct / 2 + "%",
            top: yPct - heightPct / 2 + "%",
            width: widthPct + "%",
            height: heightPct + "%",
          });

          saveBlockRect($block.data("block-id"), {
            x: xPct.toFixed(3),
            y: yPct.toFixed(3),
            width: widthPct.toFixed(3),
            height: heightPct.toFixed(3),
          });
        },
      });
    });
  }

  // ── Phase 5: style panel ────────────────────────────────────────────
  var $panel = $(".cover-style-panel");
  var $status = $panel.find(".csp-status");

  // Which CSS class values map to each attribute. Keeps the DOM-class
  // toggles in one place so a new value doesn't have to be added in
  // three spots.
  // Values as stored in the DB (== button data-value in the panel). Each
  // attribute uses a distinct class prefix so overloaded values like
  // "normal" (font_weight AND text_style) don't collide in the DOM.
  var ATTR_CLASSES = {
    font_size:   ["h1", "h2", "h3", "h4"],
    font_weight: ["normal", "semi-bold", "bold"],
    text_style:  ["normal", "italic"],
    text_align:  ["left", "center", "right"],
  };

  var CLASS_PREFIX = {
    font_weight: "weight-",
    text_style:  "style-",
    text_align:  "align-",
    // font_size has no prefix — classes are h1/h2/h3/h4 directly.
  };

  function classForValue(attr, value) {
    return (CLASS_PREFIX[attr] || "") + value;
  }

  // Font-size resolution. font_size can be a preset ("h1".."h4") or a
  // pixel number as a string (e.g. "22"). Everything eventually resolves
  // to an integer px value applied inline via the style attribute.
  var FONT_PRESET_PX = { h1: 48, h2: 32, h3: 24, h4: 18 };
  function fontSizeToPx(fontSize) {
    if (fontSize && FONT_PRESET_PX[fontSize] != null) return FONT_PRESET_PX[fontSize];
    var n = parseInt(fontSize, 10);
    return isNaN(n) || n <= 0 ? 24 : n;
  }
  function applyFontSize($block, fontSize) {
    $block.attr("data-font-size", fontSize);
    $block.css("font-size", fontSizeToPx(fontSize) + "px");
    // Keep h1-h4 class in sync for anywhere that still keys off them.
    $block.removeClass("h1 h2 h3 h4");
    if (FONT_PRESET_PX[fontSize] != null) $block.addClass(fontSize);
  }

  // Auto-fit a text block's box to its content. Measures the block at
  // max-content, converts back to % of canvas, and updates x/y so the
  // block's CENTER stays in the same place. Also persists via PATCH.
  function fitTextBlockToContent($block) {
    if ($block.hasClass("is-image")) return;
    var $text = $block.find(".cover-block-text");
    if (!$text.length) return;

    var canvasW = $canvas.width();
    var canvasH = $canvas.height();

    var origW = $block.outerWidth();
    var origH = $block.outerHeight();
    var centerX = $block.position().left + origW / 2;
    var centerY = $block.position().top  + origH / 2;

    // Measure at natural dimensions. .cover-block-text has width/height
    // 100% in CSS, which would circular-depend with the block trying to
    // size to its child — so also release the text's width/height and
    // padding during measurement.
    var savedBlockW = $block[0].style.width;
    var savedBlockH = $block[0].style.height;
    var savedTextW  = $text[0].style.width;
    var savedTextH  = $text[0].style.height;
    $block.css({ width: "max-content", height: "max-content" });
    $text .css({ width: "auto",        height: "auto"        });
    var natW = $block[0].offsetWidth;
    var natH = $block[0].offsetHeight;
    $block[0].style.width  = savedBlockW;
    $block[0].style.height = savedBlockH;
    $text [0].style.width  = savedTextW;
    $text [0].style.height = savedTextH;

    // Floor so an empty edit doesn't collapse the block to a dot.
    var fontPx = fontSizeToPx($block.attr("data-font-size"));
    natW = Math.max(natW, fontPx * 2);
    natH = Math.max(natH, fontPx);

    var widthPct  = (natW / canvasW) * 100;
    var heightPct = (natH / canvasH) * 100;
    var xPct      = (centerX / canvasW) * 100;
    var yPct      = (centerY / canvasH) * 100;

    $block.css({
      left:   xPct - widthPct  / 2 + "%",
      top:    yPct - heightPct / 2 + "%",
      width:  widthPct  + "%",
      height: heightPct + "%",
    });

    saveBlockRect($block.data("block-id"), {
      x: xPct.toFixed(3),
      y: yPct.toFixed(3),
      width:  widthPct.toFixed(3),
      height: heightPct.toFixed(3),
    });
  }

  function currentValue($block, attr) {
    var values = ATTR_CLASSES[attr];
    for (var i = 0; i < values.length; i++) {
      if ($block.hasClass(classForValue(attr, values[i]))) return values[i];
    }
    return null;
  }

  var $pxInput = $panel.find(".csp-px-input");

  function refreshPanelFromBlock($block) {
    // Image blocks don't have font/weight/style/align — disable those
    // panel buttons so they can't be clicked and don't light up.
    var isImage = $block && $block.hasClass("is-image");

    $panel.find(".csp-btn[data-attr]").each(function () {
      var attr = $(this).data("attr");
      var val = $(this).data("value");
      var applies = !isImage; // all data-attr controls are text-only
      var active = applies && $block && currentValue($block, attr) === val;
      $(this).toggleClass("is-active", !!active);
      $(this).toggleClass("is-disabled", !!(isImage && $block));
    });

    // Sync the pixel-size input with the selected block; disable it for
    // images and clear it when nothing is selected.
    $pxInput.toggleClass("is-disabled", !!(isImage && $block));
    if ($block && !isImage) {
      $pxInput.val(fontSizeToPx($block.attr("data-font-size")));
    } else {
      $pxInput.val("");
    }
  }

  function setSelected($block) {
    $canvas.find(".cover-block").removeClass("is-selected");
    if ($block && $block.length) $block.addClass("is-selected");
    refreshPanelFromBlock($block);
  }

  // Click on a block → select it. Ignore clicks that were actually the
  // start of a drag (jQuery UI fires click even after a small drag
  // sometimes, but that's fine — we still just select).
  $canvas.off("click.coverSelect").on(
    "click.coverSelect",
    ".cover-block",
    function (e) {
      if ($(e.target).closest(".cover-block-delete, .ui-resizable-handle").length) return;
      setSelected($(this));
      e.stopPropagation();
    }
  );

  // Click outside any block on the canvas or panel deselects.
  $(document).off("click.coverDeselect").on("click.coverDeselect", function (e) {
    if ($(e.target).closest(".cover-block, .cover-style-panel").length) return;
    setSelected(null);
  });

  // Style-button click. If a block is selected → modify it. If nothing
  // is selected AND this is a "size" button (H1–H4) → create a new text
  // block at that size. Other attribute buttons (weight/style/align) are
  // no-ops when no block is selected.
  $panel.off("click.coverStyle").on(
    "click.coverStyle",
    ".csp-btn[data-attr]",
    function () {
      if ($(this).hasClass("is-disabled")) return;
      var attr = $(this).data("attr");
      var value = $(this).data("value");
      var $selected = $canvas.find(".cover-block.is-selected");

      if ($selected.length) {
        if (attr === "font_size") {
          applyFontSize($selected, value);
        } else {
          var newClass = classForValue(attr, value);
          ATTR_CLASSES[attr].forEach(function (v) {
            $selected.removeClass(classForValue(attr, v));
          });
          $selected.addClass(newClass);
        }
        var payload = {};
        payload[attr] = value;
        saveBlockRect($selected.data("block-id"), payload);
        // Font size change → re-fit box to text so it hugs the content.
        if (attr === "font_size") fitTextBlockToContent($selected);
        refreshPanelFromBlock($selected);
      } else if (attr === "font_size") {
        // No selection + size button → create a new text block at that size.
        createTextBlock(value);
      }
    }
  );

  // Pixel size input — set the selected text block's font_size to the
  // typed integer (as a string) and update the inline style. Bound
  // above `initDrag()` because it depends on `applyFontSize`.
  $pxInput.off("change.coverPx input.coverPx").on(
    "change.coverPx input.coverPx",
    function () {
      var $selected = $canvas.find(".cover-block.is-selected");
      if (!$selected.length || $selected.hasClass("is-image")) return;
      var px = parseInt(this.value, 10);
      if (isNaN(px) || px < 6 || px > 240) return;
      applyFontSize($selected, String(px));
      saveBlockRect($selected.data("block-id"), { font_size: String(px) });
      fitTextBlockToContent($selected);
    }
  );

  // Trash icon: delete the currently selected block. Uses JSON Accept
  // so Rails responds 204 (no redirect chain) and removes the DOM node
  // client-side without a page reload — earlier we hit a mystery flash
  // that suggested some other code path was destroying the cover during
  // the reload window, so skipping reload eliminates the risk entirely.
  $panel.off("click.coverDelete").on(
    "click.coverDelete",
    ".csp-delete-selected",
    function () {
      var $selected = $canvas.find(".cover-block.is-selected");
      if (!$selected.length) {
        alert("Click a block first, then the trash icon deletes it.");
        return;
      }
      var id = $selected.data("block-id");
      if (!id) return;
      var url = "/blocks/" + id;
      if (!confirm("Delete this block (id " + id + ") from the cover? URL: " + url)) return;
      console.log("Deleting block via", url);
      fetch(url, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": csrfToken(),
          Accept: "application/json",
        },
      })
        .then(function (r) {
          console.log("Delete response:", r.status);
          if (!r.ok && r.status !== 204) throw new Error("Delete failed: " + r.status);
          $selected.remove();
          refreshPanelFromBlock(null);
        })
        .catch(function (err) {
          alert(err.message || "Delete failed.");
        });
    }
  );

  // Create a new text block with the given font_size (h1–h4). Uses the
  // block create endpoint with the same defaults as the old "+ Text" form.
  function createTextBlock(fontSize) {
    var params = new URLSearchParams();
    params.append("block[cover_id]",     $canvas.data("cover-id"));
    params.append("block[kind]",         "text");
    params.append("block[content]",      "New text");
    params.append("block[x]",            50);
    params.append("block[y]",            20);
    params.append("block[width]",        60);
    params.append("block[height]",       8);
    params.append("block[font_size]",    fontSize);
    params.append("block[font_weight]",  "bold");
    params.append("block[text_align]",   "center");
    fetch("/blocks", {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    }).then(function () { window.location.reload(); });
  }

  // ── Text content editing ────────────────────────────────────────────
  // Double-click a text block to enter contenteditable mode. Enter saves
  // and exits (Shift+Enter for a line break). Escape cancels without
  // saving. Blur (click outside) saves. While editing, drag/resize are
  // disabled so keyboard nav and selection work naturally.
  function enterEditMode($text) {
    var $block = $text.closest(".cover-block");
    $text.data("originalContent", $text.text());
    $text.attr("contenteditable", "true").focus();
    if ($block.data("uiDraggable")) $block.draggable("disable");
    if ($block.data("uiResizable")) $block.resizable("disable");
    // Select all so typing replaces existing content immediately.
    var range = document.createRange();
    range.selectNodeContents($text[0]);
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
  }

  function exitEditMode($text, opts) {
    opts = opts || {};
    var $block = $text.closest(".cover-block");
    // Strip contenteditable BEFORE measurement — browsers can add
    // zero-width phantom nodes to editable elements that skew size.
    $text.removeAttr("contenteditable");
    if ($block.data("uiDraggable")) $block.draggable("enable");
    if ($block.data("uiResizable")) $block.resizable("enable");

    if (opts.cancel) {
      $text.text($text.data("originalContent") || "");
    } else {
      saveBlockRect($block.data("block-id"), {
        content: $text.text().trim(),
      });
      fitTextBlockToContent($block);
    }
  }

  $canvas.off("dblclick.coverEdit").on(
    "dblclick.coverEdit",
    ".cover-block-text",
    function (e) {
      e.stopPropagation();
      enterEditMode($(this));
    }
  );

  // blur doesn't bubble; use focusout for delegation.
  $canvas.off("focusout.coverEdit").on(
    "focusout.coverEdit",
    '.cover-block-text[contenteditable="true"]',
    function () {
      exitEditMode($(this));
    }
  );

  $canvas.off("keydown.coverEdit").on(
    "keydown.coverEdit",
    '.cover-block-text[contenteditable="true"]',
    function (e) {
      if (e.key === "Escape") {
        e.preventDefault();
        exitEditMode($(this), { cancel: true });
        $(this).blur();
      } else if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        $(this).blur();     // triggers focusout → save & exit
      }
    }
  );

  // ── Image upload form ──────────────────────────────────────────────
  // Flow:
  //   1. User clicks the image button in the panel.
  //      • If an image block is selected → open uploader for it.
  //      • Otherwise → AJAX-create a new placeholder image block, then
  //        open uploader for the new block once the page reloads.
  //   2. User picks a file in the form → preview shown in the target
  //      block (via URL.createObjectURL).
  //   3. User clicks Upload → PATCH /blocks/:id with the file → reload.
  //   4. Cancel closes the form without uploading.
  var $uploadForm  = $(".cover-upload-form");
  var $fileInput   = $uploadForm.find(".cui-file-input");
  var $chooseBtn   = $uploadForm.find(".cui-choose-btn");
  var $filename    = $uploadForm.find(".cui-filename");
  var $uploadBtn   = $uploadForm.find(".cui-upload-btn");
  var $cancelBtn   = $uploadForm.find(".cui-cancel-btn");
  var previewObjectUrl = null;

  function openImageUploader(blockId) {
    if (blockId === undefined || blockId === null || blockId === "") {
      alert("Could not open uploader: no target block id.");
      return;
    }
    // .attr() with undefined-as-value is a getter, so pass a plain string.
    $uploadForm.attr("data-target-block-id", String(blockId)).addClass("is-open");
    $fileInput.val("");
    $filename.text("No file chosen");
    $uploadBtn.prop("disabled", true);
  }

  function closeImageUploader() {
    if (previewObjectUrl) {
      URL.revokeObjectURL(previewObjectUrl);
      previewObjectUrl = null;
    }
    $uploadForm.removeClass("is-open").attr("data-target-block-id", "");
    $fileInput.val("");
  }

  function targetImageBlock() {
    var id = $uploadForm.attr("data-target-block-id");
    return id ? $canvas.find('[data-block-id="' + id + '"]') : $();
  }

  $chooseBtn.off("click.coverImgChoose").on("click.coverImgChoose", function () {
    $fileInput.trigger("click");
  });

  $cancelBtn.off("click.coverImgCancel").on("click.coverImgCancel", closeImageUploader);

  // File selected — preview inside the target block AND shrink the
  // block so its aspect ratio matches the picked image (no whitespace).
  $fileInput.off("change.coverImgPick").on("change.coverImgPick", function () {
    var file = this.files && this.files[0];
    if (!file) return;
    $filename.text(file.name);
    $uploadBtn.prop("disabled", false);

    if (previewObjectUrl) URL.revokeObjectURL(previewObjectUrl);
    previewObjectUrl = URL.createObjectURL(file);
    var $block = targetImageBlock();
    $block.find(".cover-block-image, .cover-block-image-placeholder").remove();
    var $img = $('<img class="cover-block-image">').attr("src", previewObjectUrl);
    $block.prepend($img);

    // Once the preview loads, fit the block to the image's aspect ratio
    // by shrinking the too-large dimension. Keep the center in place so
    // the block doesn't jump.
    $img.on("load", function () {
      var natW = this.naturalWidth;
      var natH = this.naturalHeight;
      if (!natW || !natH) return;

      var canvasW = $canvas.width();
      var canvasH = $canvas.height();
      var blockW  = $block.outerWidth();
      var blockH  = $block.outerHeight();
      var imgAR   = natW / natH;
      var blockAR = blockW / blockH;

      var newW = blockW;
      var newH = blockH;
      if (blockAR > imgAR) newW = blockH * imgAR;
      else                 newH = blockW / imgAR;

      var centerXpx = $block.position().left + blockW / 2;
      var centerYpx = $block.position().top  + blockH / 2;
      var widthPct  = (newW / canvasW) * 100;
      var heightPct = (newH / canvasH) * 100;
      var xPct      = (centerXpx / canvasW) * 100;
      var yPct      = (centerYpx / canvasH) * 100;

      $block.css({
        left:   xPct - widthPct  / 2 + "%",
        top:    yPct - heightPct / 2 + "%",
        width:  widthPct  + "%",
        height: heightPct + "%",
      });
    });
  });

  // Upload button — send the file + the block's current (fit-to-image)
  // dimensions to /blocks/:id, so the persisted rectangle matches the
  // picture rather than the pre-upload placeholder box.
  $uploadBtn.off("click.coverImgUpload").on("click.coverImgUpload", function () {
    var file = $fileInput[0].files[0];
    if (!file) return;
    var blockId = $uploadForm.attr("data-target-block-id");
    if (!blockId) {
      alert("No target block id — upload aborted.");
      return;
    }

    var $block = targetImageBlock();
    var canvasW = $canvas.width();
    var canvasH = $canvas.height();
    var centerXpx = $block.position().left + $block.outerWidth()  / 2;
    var centerYpx = $block.position().top  + $block.outerHeight() / 2;
    var widthPct  = ($block.outerWidth()  / canvasW) * 100;
    var heightPct = ($block.outerHeight() / canvasH) * 100;
    var xPct      = (centerXpx / canvasW) * 100;
    var yPct      = (centerYpx / canvasH) * 100;

    var formData = new FormData();
    formData.append("block[main_image]", file);
    formData.append("block[width]",  widthPct.toFixed(3));
    formData.append("block[height]", heightPct.toFixed(3));
    formData.append("block[x]",      xPct.toFixed(3));
    formData.append("block[y]",      yPct.toFixed(3));
    formData.append("_method", "patch");
    formData.append("authenticity_token", csrfToken());

    $uploadBtn.prop("disabled", true).text("Uploading…");
    fetch("/blocks/" + blockId, {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken() },
      body: formData,
    })
      .then(function (r) {
        if (!r.ok) throw new Error("Upload failed: " + r.status);
        closeImageUploader();
        window.location.reload();
      })
      .catch(function (err) {
        alert(err.message || "Image upload failed.");
        $uploadBtn.prop("disabled", false).text("Upload");
      });
  });

  // Image button in the panel — open the uploader (create block first
  // if needed). We stash the new block's id in sessionStorage across the
  // page reload so the uploader can auto-open for it.
  $panel.off("click.coverAddImage").on("click.coverAddImage", ".csp-add-image", function () {
    var $selected = $canvas.find(".cover-block.is-selected");
    if ($selected.length && $selected.hasClass("is-image")) {
      openImageUploader($selected.data("block-id"));
      return;
    }

    // Create a new image block, then reload and auto-open the uploader.
    var params = new URLSearchParams();
    params.append("block[cover_id]",      $canvas.data("cover-id"));
    params.append("block[kind]",          "image");
    params.append("block[image_block]",   "true");
    params.append("block[x]",             50);
    params.append("block[y]",             40);
    params.append("block[width]",         50);
    params.append("block[height]",        30);

    fetch("/blocks.json", {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: params.toString(),
    })
      .then(function (r) {
        if (!r.ok) throw new Error("Create failed: " + r.status);
        return r.json();
      })
      .then(function (data) {
        if (!data || !data.id) throw new Error("Create response missing id");
        try { sessionStorage.setItem("cover_open_uploader", String(data.id)); } catch (e) {}
        window.location.reload();
      })
      .catch(function (err) { alert(err.message || "Could not create image block."); });
  });

  // Trash icon: delete the currently selected block. (Moved here from
  // the earlier location so image-related handlers are grouped.)
  // (Delete handler is defined above in the style-panel section.)

  // Auto-open the uploader if we just created a fresh image block.
  try {
    var pendingId = sessionStorage.getItem("cover_open_uploader");
    if (pendingId) {
      sessionStorage.removeItem("cover_open_uploader");
      // Wait a tick for the canvas DOM to render the new block.
      setTimeout(function () { openImageUploader(pendingId); }, 0);
    }
  } catch (e) {}

  initDrag();
  initResize();
  refreshPanelFromBlock(null);
});
