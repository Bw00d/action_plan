$(document).on('turbolinks:load', function () {
  var $index = $('.requests-index');
  if (!$index.length) return;

  // Individual caret toggle (click or keyboard-activate on the span[role=button])
  function toggleRequest($btn) {
    var key = $btn.data('target');
    var expanded = $btn.attr('aria-expanded') === 'true';
    $btn.attr('aria-expanded', String(!expanded));
    $btn.closest('table').find('tr.request-child[data-child-of="' + key + '"]').toggleClass('is-hidden', expanded);
  }

  $index.on('click', '.request-toggle', function () {
    toggleRequest($(this));
  });

  $index.on('keydown', '.request-toggle', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleRequest($(this));
    }
  });

  // Click on Req # text expands the detail row (check-in area).
  function toggleDetail($el) {
    var key = $el.data('detail-target');
    $el.closest('table').find('tr.request-detail[data-detail-of="' + key + '"]').toggleClass('is-hidden');
  }

  $index.on('click', '.req-number-text[data-detail-target]', function () {
    toggleDetail($(this));
  });

  $index.on('keydown', '.req-number-text[data-detail-target]', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleDetail($(this));
    }
  });

  // ── Search filter ─────────────────────────────────────────────────────
  var $searchInput   = $('#requests-search-input');
  var $searchClear   = $('#requests-search-clear');
  var $searchSummary = $('#requests-search-summary');

  function normalize(s) { return (s || '').toString().toLowerCase(); }

  function applySearch() {
    var q = normalize($searchInput.val()).trim();
    var hasQuery = q.length > 0;
    $searchClear.toggle(hasQuery);

    var totalMatches = 0;

    $('.catalog-section', $index).each(function () {
      var $section = $(this);
      var sectionMatches = 0;

      $section.find('tr.request-parent').each(function () {
        var $parent = $(this);
        var key = $parent.data('parent-key');
        var $children = $section.find('tr.request-child[data-child-of="' + key + '"]');

        var parentText = normalize($parent.text());
        var parentMatch = !hasQuery || parentText.indexOf(q) !== -1;

        var childMatchCount = 0;
        $children.each(function () {
          var $c = $(this);
          var match = !hasQuery || normalize($c.text()).indexOf(q) !== -1;
          if (match) childMatchCount += 1;

          if (!hasQuery) {
            $c.addClass('is-hidden');
          } else if (match) {
            $c.removeClass('is-hidden');
          } else {
            $c.addClass('is-hidden');
          }
        });

        var visibleParent = parentMatch || childMatchCount > 0;
        $parent.toggleClass('is-hidden', !visibleParent);

        // The detail row follows the parent — hide it while filtering.
        $section.find('tr.request-detail[data-detail-of="' + key + '"]').addClass('is-hidden');

        // Sync the caret expanded-state to reflect what's visible.
        var $toggle = $parent.find('.request-toggle');
        if ($toggle.length) {
          var expanded = childMatchCount > 0 && hasQuery;
          $toggle.attr('aria-expanded', String(expanded));
        }

        if (visibleParent) {
          sectionMatches += 1 + childMatchCount;
        }
      });

      $section.toggleClass('is-empty', hasQuery && sectionMatches === 0);
      totalMatches += sectionMatches;
    });

    if (hasQuery) {
      $searchSummary.text(totalMatches + ' match' + (totalMatches === 1 ? '' : 'es'));
    } else {
      $searchSummary.text('');
    }
  }

  $searchInput.on('input', applySearch);
  $searchClear.on('click', function () {
    $searchInput.val('').focus();
    applySearch();
  });
});
