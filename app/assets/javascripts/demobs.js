// Demob checkout form: PRINT is always visible; SUBMIT only shows once
// the Actual Release Date field has a value. Applies to both regular
// resource demobs and roster (subordinate) demobs. show.html.erb sets
// the initial .rd-hidden state server-side so there's no flicker.
var demobReleasePoll = null;

$(document).on("turbolinks:load", function () {
  // Turbolinks keeps window state across visits — stop the previous
  // page's poll before (maybe) starting a new one.
  if (demobReleasePoll) {
    clearInterval(demobReleasePoll);
    demobReleasePoll = null;
  }

  var $submitBtn = $('#demob-form-button');
  if (!$submitBtn.length) return;

  var $releaseField = $('input[name="demob[actual_release_date]"]');

  // Safety net: field missing → never strand the user without SUBMIT.
  if (!$releaseField.length) {
    $submitBtn.removeClass('rd-hidden');
    return;
  }

  function toggleSubmit() {
    var hasDate = ($releaseField.val() || '').toString().trim().length > 0;
    $submitBtn.toggleClass('rd-hidden', !hasDate);
  }

  $releaseField.on('change input keyup blur changeDate paste', toggleSubmit);

  // Poll (200ms) catches silent value changes from the datepicker popup
  // that don't fire a normal event.
  var lastVal = $releaseField.val() || '';
  demobReleasePoll = setInterval(function () {
    var now = $releaseField.val() || '';
    if (now !== lastVal) { lastVal = now; toggleSubmit(); }
  }, 200);

  toggleSubmit();
});
