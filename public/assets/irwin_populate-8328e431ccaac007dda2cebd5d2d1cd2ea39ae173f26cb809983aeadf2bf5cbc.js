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
    ownership: 'Ownership'
    // 'p_code' removed — financial codes are now a separate first-class model
  };

  $btn.on('click', function () {
    $status.text('Fetching from IRWIN…');
    $body.empty();

    $.getJSON($btn.data('url'))
      .done(function (data) {
        var proposed = data.proposed || {};
        var proposedCodes = data.financial_codes || {};
        var rows = '';

        // Standard incident fields.
        Object.keys(FIELD_LABELS).forEach(function (field) {
          if (!(field in proposed)) return;
          var current  = currentValue(field);
          var newValue = proposed[field];
          if (current === String(newValue)) return;
          var checkboxId = 'irwin-check-' + field;
          rows += '<tr>' +
            '<td><input type="checkbox" class="irwin-check" checked id="' + checkboxId + '" data-field="' + field + '" data-value="' + $('<div>').text(newValue).html().replace(/"/g, '&quot;') + '"></td>' +
            '<td><label for="' + checkboxId + '">' + FIELD_LABELS[field] + '</label></td>' +
            '<td class="text-muted">' + $('<div>').text(current || '—').html() + '</td>' +
            '<td><strong>' + $('<div>').text(newValue).html() + '</strong></td>' +
            '</tr>';
        });

        // Financial codes (BLM, USFS). Compared against the current value
        // of the matching agency row in the info panel.
        Object.keys(proposedCodes).forEach(function (agency) {
          var newValue = proposedCodes[agency];
          if (!newValue) return;
          var current = currentFinancialCode(agency);
          if (current === String(newValue)) return;
          var checkboxId = 'irwin-check-fc-' + agency;
          rows += '<tr>' +
            '<td><input type="checkbox" class="irwin-check-fc" checked id="' + checkboxId + '" data-agency="' + agency + '" data-value="' + $('<div>').text(newValue).html().replace(/"/g, '&quot;') + '"></td>' +
            '<td><label for="' + checkboxId + '">' + agency + ' code</label></td>' +
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
        var fieldCount = Object.keys(proposed).length + Object.keys(proposedCodes).length;
        $status.text('Fetched ' + fieldCount + ' fields from IRWIN.');
        $modal.modal('show');
      })
      .fail(function (xhr) {
        var msg = (xhr.responseJSON && xhr.responseJSON.error) ||
                  ('Fetch failed (' + xhr.status + ')');
        $status.text(msg).css('color', '#b71c1c');
      });
  });

  // Read the current code value for an agency from the info panel's
  // financial-codes table. Agencies are stored uppercase.
  function currentFinancialCode(agency) {
    var wanted = agency.toString().toUpperCase();
    var found = '';
    $('.financial-codes-table tr').each(function () {
      var rowAgency = $.trim($(this).find('.fc-agency .best_in_place').text()).toUpperCase();
      if (rowAgency === wanted) {
        found = $.trim($(this).find('.fc-code .best_in_place').text());
        return false; // break
      }
    });
    return found;
  }

  $apply.on('click', function () {
    var selected = {};
    $('.irwin-check:checked').each(function () {
      selected[$(this).data('field')] = $(this).data('value');
    });

    var codes = {};
    $('.irwin-check-fc:checked').each(function () {
      codes[$(this).data('agency')] = $(this).data('value');
    });

    if ($.isEmptyObject(selected) && $.isEmptyObject(codes)) {
      $modal.modal('hide');
      return;
    }

    var csrf = $('meta[name=csrf-token]').attr('content');
    var updateUrl = $btn.data('update-url');
    var codesUrl  = updateUrl + '/financial_codes/apply_irwin';

    // Chain the two requests: incident update first, then financial codes.
    var incidentReq = $.isEmptyObject(selected)
      ? $.Deferred().resolve()
      : $.ajax({
          url: updateUrl,
          method: 'POST',
          data: { incident: selected, _method: 'patch', authenticity_token: csrf },
          dataType: 'text'
        });

    incidentReq.then(function () {
      if ($.isEmptyObject(codes)) return $.Deferred().resolve();
      return $.ajax({
        url: codesUrl,
        method: 'POST',
        data: { codes: codes, authenticity_token: csrf },
        dataType: 'json'
      });
    }).done(function () {
      window.location.href = updateUrl;
    }).fail(function (xhr) {
      alert('Update failed: ' + xhr.status + ' ' + (xhr.responseText || ''));
    });
  });
});
