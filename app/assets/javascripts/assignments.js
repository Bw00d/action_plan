// best_in_place's default sanitizeValue runs jQuery.trim, which strips
// leading/trailing whitespace — including the blank lines operators
// intentionally type into sections 6/7 to pad the field for hand
// notes on the printed 204. Patch sanitizeValue to skip trimming on
// those two fields; every other best_in_place field keeps default
// trimming behavior.
if (typeof BestInPlaceEditor !== 'undefined' && BestInPlaceEditor.prototype) {
  var _bipOrigSanitize = BestInPlaceEditor.prototype.sanitizeValue;
  BestInPlaceEditor.prototype.sanitizeValue = function (s) {
    if (this.element && this.element.closest('.box-6, .box-7').length) {
      return (s == null) ? '' : String(s);
    }
    return _bipOrigSanitize.call(this, s);
  };
}

$(document).on("turbolinks:load", function() {


  $('table#assigned-resources').hover(function() {
        $('#assign-resources-button').show();
      }, 
      function () {
        $('#assign-resources-button').hide();
      }
    );
  $('#assign-resources-button').hover(function() {
      $(this).show();
    }, 
    function () {
      $(this).hide();
    }
  );

  // ICS 204 WF Section 8: open/close the freq picker and pre-check
  // previously selected freqs when the form is shown.
  $(document).on("click", "#add-freqs-button", function () {
    $("#freq-form").show();
    if (typeof freqIds !== "undefined") {
      for (var i = 0; i < freqIds.length; i++) {
        $("#assignment_commo_item_ids_" + freqIds[i]).prop("checked", true);
      }
    }
  });
  $(document).on("click", "#cancel-freq-form", function () {
    $("#freq-form").hide();
  });

  // ICS 204 WF: flatpickr date/time pickers with auto-save PATCH.
  if (typeof flatpickr !== "undefined") {
    var autoSave = function (selectedDates, dateStr, instance) {
      var $el  = $(instance.input);
      var data = {};
      data[$el.data("field")] = dateStr;
      $.ajax({ url: $el.data("url"), type: "PATCH", data: data, dataType: "json" });
    };

    // Section 2: full date + time for ops period.
    flatpickr(".op-dt-picker", {
      enableTime: true,
      time_24hr: true,
      dateFormat: "m/d/Y H:i",
      allowInput: true,
      onChange: autoSave
    });

    // Section 9: separate date and 24h time for "prepared by" fields.
    flatpickr(".prepared-date-picker", {
      dateFormat: "m/d/Y",
      allowInput: true,
      onChange: autoSave
    });
    flatpickr(".prepared-time-picker", {
      enableTime: true,
      noCalendar: true,
      time_24hr: true,
      dateFormat: "H:i",
      allowInput: true,
      onChange: autoSave
    });
  }

  $('#assign-resources-button').click(function() {    // adding resources
    $('#resource-assignments-form').show();
  
    var i;
     for (i = 0; i < resourceIds.length; i++) {
      $("#assignment_resource_ids_" + resourceIds[i] ).prop("checked","true");
    }
  }); 
  $('#cancel-resource-assignments-form').click(function() {
    $('#resource-assignments-form').hide();
  });

  // Fallback newline formatter for sections 6/7 of the 204. The
  // server's display_with Proc already renders <br> for every newline
  // on save, so normally this is a no-op. We only kick in if the
  // response somehow landed as raw text (<br>-free) with embedded
  // newlines — convert them to <br> so blank lines survive.
  function reapplyNarrativeFormat($el) {
    var html = $el.html();
    if (html == null) return;
    if (/<br\s*\/?>/i.test(html)) return;            // server already formatted
    var text = $el.text();
    if (text == null || text.indexOf('\n') === -1) return;
    var escaped = text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
    $el.html(escaped.replace(/\n/g, '<br>'));
  }

  $(document).off('best_in_place:success.ics204Narrative')
             .on('best_in_place:success.ics204Narrative',
                 '.box-6 .best_in_place, .box-7 .best_in_place',
                 function () { reapplyNarrativeFormat($(this)); });

});