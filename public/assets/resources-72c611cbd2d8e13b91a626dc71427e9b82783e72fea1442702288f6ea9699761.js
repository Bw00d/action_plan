$(document).on("turbolinks:load", function() {

  $('.datepicker').datepicker({
    assumeNearbyYear: true,
    autoclose: true,
    todayHighlight: true
  });

  // ICS-211 client-side search
  (function () {
    var $panel = $('#ics-211-info');
    if (!$panel.length) return;
    var $search  = $panel.find('.ics-211-search-input');
    var $clear   = $panel.find('.ics-211-search-clear');
    var $summary = $panel.find('.ics-211-search-summary');
    var $tbody   = $panel.find('#incident-resources');
    if (!$search.length || !$tbody.length) return;

    function normalize(s) { return (s || '').toString().toLowerCase(); }
    function isHeaderRow($tr) { return $tr.find('td.grayed strong').length > 0; }

    function applySearch() {
      var q = normalize($search.val()).trim();
      var hasQuery = q.length > 0;
      $clear.toggle(hasQuery);

      if (!hasQuery) {
        $tbody.find('tr').show();
        $summary.text('');
        return;
      }

      var matches = 0;
      var $currentHeader = null;
      var currentHeaderHasMatch = false;

      $tbody.find('tr').each(function () {
        var $tr = $(this);
        if (isHeaderRow($tr)) {
          if ($currentHeader) $currentHeader.toggle(currentHeaderHasMatch);
          $currentHeader = $tr;
          currentHeaderHasMatch = false;
          return;
        }
        var match = normalize($tr.text()).indexOf(q) !== -1;
        $tr.toggle(match);
        if (match) {
          matches += 1;
          currentHeaderHasMatch = true;
        }
      });
      if ($currentHeader) $currentHeader.toggle(currentHeaderHasMatch);

      $summary.text(matches + ' match' + (matches === 1 ? '' : 'es'));
    }

    $search.on('input', applySearch);
    $clear.on('click', function () {
      $search.val('').focus();
      applySearch();
    });
  })();

  // Auto-size best_in_place inputs to fit their content. Modern browsers
  // handle this via CSS `field-sizing: content`; this is the fallback that
  // sets the `size` attribute for browsers that don't yet support it.
  var supportsFieldSizing = window.CSS && CSS.supports && CSS.supports('field-sizing', 'content');
  if (!supportsFieldSizing) {
    $(document).on('focus', '.sm-bip-input input, .md-bip-input input, .lg-bip-input input', function () {
      var $input = $(this);
      function resize() {
        $input.attr('size', Math.max(($input.val() || '').length + 2, 4));
      }
      resize();
      $input.on('input.bipResize', resize);
      $input.one('blur.bipResize', function () { $input.off('.bipResize'); });
    });
  }
  
  $('select#resource_category').change(function() {
    var text = $(this).val();
    $('#order-number-input').show();
    switch(text) {
    case 'EQUIPMENT':  
      var prefix = 'E-'
     break;

    case 'CREW':  
      var prefix = 'C-'
      break;

    case 'OVERHEAD':
      var prefix = 'O-'
      break;

    case 'AIRCRAFT':
      var prefix = 'A-'
      break;
    }
      $('.order-number-prefix').html( prefix )

  });

 // Style glide rows
 //   demob day (LWD + 1) → black
 //   LWD                 → red
 //   LWD - 1, LWD - 2    → orange   (2 days before)
 //   LWD - 3..LWD - 5    → yellow   (3 days before that)
 //   anything earlier    → green
   $( ".glide-row" ).each( function( index, element ) {
      const day = Date.parse($(this).attr('data-day'))
      const lwd = Date.parse($(this).attr('data-lwd'))
      if (isNaN(lwd)) return;
      const ONE_DAY = 86400000;
      const demob_day = lwd + ONE_DAY;
      if (day === lwd) {
        $(this).addClass('red');
        $(this).text('LWD');
      } else if (day === demob_day) {
        $(this).addClass('black');
        $(this).text('DMB');
      } else if (day < lwd && day >= lwd - 2 * ONE_DAY) {
        $(this).addClass('orange');
      } else if (day < lwd - 2 * ONE_DAY && day >= lwd - 5 * ONE_DAY) {
        $(this).addClass('yellow');
      } else if (day < lwd - 5 * ONE_DAY) {
        $(this).addClass('green');
      }
  });


// tabrows

  $('a.resource-tab-link').click(function() {
    $('.resource-tab').removeClass('selected');
    $(this).parent().addClass('selected');
  })
  $('a#ics-211-tab').click(function (){
    $('#ics-211-info').show();
    $('#demob-info').hide();
    $('#glide-info').hide();
    $('#tally-info').hide();
  })
  $('a#glide-tab').click(function (){
    $('#ics-211-info').hide();
    $('#demob-info').hide();
    $('#glide-info').show();
    $('#tally-info').hide();
  })
  $('a#demob-tab').click(function (){
    $('#ics-211-info').hide();
    $('#glide-info').hide();
    $('#demob-info').show();
    $('#tally-info').hide();
  })
  $('a#tally-tab').click(function (){
    $('#ics-211-info').hide();
    $('#glide-info').hide();
    $('#demob-info').hide();
    $('#tally-info').show();
  })

// Reload page after creating resource
  // $('#submit-resource-button').click(function() {
  //   window.location.reload();
  // })

  // submitting forms

  $(".rnr-form-button").on("click", function (){
    $(this).parents('form:first').submit();
  });

    $(".fwd-datepicker").on("change", function (){
    $(this).parents('form:first').trigger('submit.rails');
    $('.datepicker-dropdown').hide();
  });


  // Double-click a resource row → open its floating detail panel with all
  // editable attributes. Close with the X, backdrop click, or Escape.
  $(document).on('dblclick', 'tr.incident-resource', function (e) {
    if ($(e.target).closest('.best_in_place, input, textarea, select, a, button, .resource-roster-toggle').length) return;
    var id = $(this).attr('id').replace('resource-', '');
    $('.resource-panel').addClass('is-hidden');
    $('#resource-panel-' + id).removeClass('is-hidden');
  });

  // Roster expansion — click the caret in the Order # cell to toggle
  // visibility of the roster rows nested below the parent resource row.
  function toggleRosterExpansion($btn) {
    var id = $btn.data('resource-id');
    var expanded = $btn.attr('aria-expanded') === 'true';
    $btn.attr('aria-expanded', String(!expanded));
    $('tr.resource-roster-row[data-resource-id="' + id + '"]').toggleClass('is-hidden', expanded);
  }

  // Namespaced + off/on so turbolinks:load re-firing (e.g. after a remote
  // form redirect) doesn't stack multiple handlers on document. Two handlers
  // would flip aria-expanded twice per click and the caret would look dead.
  $(document).off('click.rosterToggle').on('click.rosterToggle', '.resource-roster-toggle', function (e) {
    e.stopPropagation();
    toggleRosterExpansion($(this));
  });

  $(document).off('keydown.rosterToggle').on('keydown.rosterToggle', '.resource-roster-toggle', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleRosterExpansion($(this));
    }
  });

  $(document).on('click', '.resource-panel-close', function () {
    $(this).closest('.resource-panel').addClass('is-hidden');
  });

  // Backdrop click closes; clicks inside .resource-panel-inner don't bubble to hide.
  $(document).on('click', '.resource-panel', function (e) {
    if (e.target === this) $(this).addClass('is-hidden');
  });

  $(document).on('keydown', function (e) {
    if (e.key === 'Escape') $('.resource-panel').addClass('is-hidden');
  });

  
});
