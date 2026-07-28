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

  // ICS 204 WF: 24h flatpickr date/time pickers for Section 2 ops period.
  // The picker's onChange fires the AJAX PATCH to auto-save.
  if (typeof flatpickr !== "undefined") {
    flatpickr(".op-dt-picker", {
      enableTime: true,
      time_24hr: true,
      dateFormat: "m/d/Y H:i",
      allowInput: true,
      onChange: function (selectedDates, dateStr, instance) {
        var $el  = $(instance.input);
        var data = {};
        data[$el.data("field")] = dateStr;
        $.ajax({ url: $el.data("url"), type: "PATCH", data: data, dataType: "json" });
      }
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


});