// IRWIN populate — fetches WFIGS/IRWIN attributes for the current incident,
// shows a modal with a current-vs-proposed diff, and PATCHes the incident
// with only the fields the user checked.
$(document).on('turbolinks:load', function () {
  var $btn = $('#irwin-populate-btn');
  if (!$btn.length) return;

  var $status = $('#irwin-status');
  var $modal  = $('#irwin-modal');
  var $body   = $('#irwin-diff-body');
  var $apply  = $('#irwin-apply-btn');
  var $form   = $('#irwin-apply-form');

  // Display helpers for the current values in the info panel. We reach into
  // the panel's rendered text so we don't have to duplicate model → label
  // knowledge in JS.
  function currentValue(field) {
    // best_in_place spans have data-attribute matching the field name.
    var $span = $('.best_in_place[data-attribute="' + field + '"]').first();
    if ($span.length) return $.trim($span.text());
    return '';
  }

  var FIELD_LABELS = {
    name: 'Name',
    number: 'Number',
    size: 'Size (acres)',
    percent_contained: '% Contained',
    status: 'Status',
    cost: 'Estimated Cost',
    cause: 'Cause',
    fire_behavior: 'Activity',
    fuel_type: 'Fuels',
    start_date: 'Start Date',
    containment_date: 'Contained Date',
    control_date: 'Controlled Date',
    out_date: 'Out Date',
    location: 'Location',
    latitude: 'Latitude',
    longitude: 'Longitude',
    ic: 'IC',
    complexity: 'Complexity',
    ownership: 'Ownership',
    p_code: 'P Code'
  };

  $btn.on('click', function () {
    $status.text('Fetching from IRWIN…');
    $body.empty();

    $.getJSON($btn.data('url'))
      .done(function (data) {
        var proposed = data.proposed || {};
        var rows = '';
        Object.keys(FIELD_LABELS).forEach(function (field) {
          if (!(field in proposed)) return;
          var current  = currentValue(field);
          var newValue = proposed[field];
          if (current === String(newValue)) return; // no change; hide it
          var checkboxId = 'irwin-check-' + field;
          rows += '<tr>' +
            '<td><input type="checkbox" class="irwin-check" checked id="' + checkboxId + '" data-field="' + field + '" data-value="' + $('<div>').text(newValue).html().replace(/"/g, '&quot;') + '"></td>' +
            '<td><label for="' + checkboxId + '">' + FIELD_LABELS[field] + '</label></td>' +
            '<td class="text-muted">' + $('<div>').text(current || '—').html() + '</td>' +
            '<td><strong>' + $('<div>').text(newValue).html() + '</strong></td>' +
            '</tr>';
        });

        if (!rows) {
          rows = '<tr><td colspan="4" class="text-center text-muted"><em>IRWIN has no fields that differ from what\'s already saved.</em></td></tr>';
          $apply.prop('disabled', true);
        } else {
          $apply.prop('disabled', false);
        }
        $body.html(rows);
        $status.text('Fetched ' + Object.keys(proposed).length + ' fields from IRWIN.');
        $modal.modal('show');
      })
      .fail(function (xhr) {
        var msg = (xhr.responseJSON && xhr.responseJSON.error) ||
                  ('Fetch failed (' + xhr.status + ')');
        $status.text(msg).css('color', '#b71c1c');
      });
  });

  $apply.on('click', function () {
    var selected = {};
    $('.irwin-check:checked').each(function () {
      selected[$(this).data('field')] = $(this).data('value');
    });
    if ($.isEmptyObject(selected)) {
      $modal.modal('hide');
      return;
    }

    // Build the same nested params shape Rails expects: incident[field].
    var payload = { incident: selected, _method: 'patch',
                    authenticity_token: $('meta[name=csrf-token]').attr('content') };

    $.ajax({
      url: $btn.data('update-url'),
      method: 'POST',
      data: payload,
      dataType: 'text'
    })
      .done(function () {
        // The IncidentsController#update action redirects to the plans
        // page by default; force navigation back to the incident show
        // page so users land somewhere useful for reviewing IRWIN edits.
        window.location.href = $btn.data('update-url');
      })
      .fail(function (xhr) {
        alert('Update failed: ' + xhr.status + ' ' + (xhr.responseText || ''));
      });
  });
});
