$(document).on("turbolinks:load", function () {
  var $printBtn  = $('#print-demob-button');
  var $submitBtn = $('#demob-form-button');
  var $rosterButtons = $('.roster-demob-buttons');
  var isRosterDemob = $rosterButtons.length && $printBtn.length && $submitBtn.length;

  if (isRosterDemob) {
    // Roster (subordinate) demob: PRINT shows until the actual release
    // date field has a value, then SUBMIT takes over. Toggle a class
    // on the buttons themselves (not wrapper divs) so there's no
    // float-collapse or layout-context weirdness.
    var $releaseField = $('#demob_actual_release_date');
    if (!$releaseField.length) $releaseField = $('input[name="demob[actual_release_date]"]');

    function toggleRosterButtons() {
      var val = $releaseField.length ? ($releaseField.val() || '') : '';
      var hasDate = val.toString().trim().length > 0;
      $printBtn.css('display',  '').toggleClass('rd-hidden',  hasDate);
      $submitBtn.css('display', '').toggleClass('rd-hidden', !hasDate);
    }

    // Safety net: field missing → show both buttons.
    if (!$releaseField.length) {
      $printBtn.removeClass('rd-hidden');
      $submitBtn.removeClass('rd-hidden');
      return;
    }

    $releaseField.on('change input keyup blur changeDate paste', toggleRosterButtons);
    $(document).on('change input keyup blur changeDate paste',
                   'input[name="demob[actual_release_date]"]',
                   toggleRosterButtons);

    // Continuous poll (200ms) catches silent value changes from the
    // datepicker popup that don't bubble a normal event.
    var lastVal = $releaseField.val() || '';
    setInterval(function () {
      var now = ($('input[name="demob[actual_release_date]"]').val() || '');
      if (now !== lastVal) { lastVal = now; toggleRosterButtons(); }
    }, 200);

    toggleRosterButtons();
    return;
  }

  // Regular resource demob: any input change hides PRINT and reveals
  // the always-in-DOM SUBMIT button. Unchanged legacy behavior.
  $("#demob-form :input").change(function () {
    $('#print-demob-button').hide();
    $('#demob-form-button').show();
  });
});

