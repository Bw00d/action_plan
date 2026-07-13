$(document).on('turbolinks:load', function () {
  var $index = $('.requests-index');
  if (!$index.length) return;

  // Persistent search filter state. When a search is active this is an
  // object { rowId: true, ... } listing every row that survives the
  // filter (matches plus their ancestor chain). Null when no search.
  var searchVisibleIds = null;

  // Refresh visibility of every tree row from three inputs:
  //   1. ancestor-collapse — hide if any ancestor toggle is collapsed
  //   2. detail user-open — details only show when the user opened them
  //   3. search filter — if active, hide rows outside the visible set
  // All three combine; a row is visible only if none of them hide it.
  function refreshTreeVisibility() {
    var collapsedKeys = {};
    $index.find('.request-toggle[aria-expanded="false"]').each(function () {
      collapsedKeys[$(this).data('target')] = true;
    });

    var searchActive = searchVisibleIds !== null;

    $index.find('tr[data-ancestors]').each(function () {
      var $row = $(this);
      var attr = String($row.attr('data-ancestors') || '').trim();
      var ancestors = attr.length ? attr.split(/\s+/) : [];
      var ancestorCollapsed = false;
      for (var i = 0; i < ancestors.length; i++) {
        if (collapsedKeys[ancestors[i]]) { ancestorCollapsed = true; break; }
      }

      if ($row.hasClass('request-detail')) {
        var userOpen = $row.hasClass('is-detail-open');
        var searchHidden = false;
        if (searchActive) {
          searchHidden = !searchVisibleIds[$row.data('detail-of')];
        }
        $row.toggleClass('is-hidden', !userOpen || ancestorCollapsed || searchHidden);
      } else {
        var searchHiddenRow = false;
        if (searchActive) {
          searchHiddenRow = !searchVisibleIds[$row.data('parent-key')];
        }
        $row.toggleClass('is-hidden', ancestorCollapsed || searchHiddenRow);
      }
    });
  }

  // Caret click: toggle this node's expanded state, then refresh visibility
  // for the whole tree.
  function toggleTreeNode($btn) {
    var expanded = $btn.attr('aria-expanded') === 'true';
    $btn.attr('aria-expanded', String(!expanded));
    refreshTreeVisibility();
  }

  $index.on('click', '.request-toggle', function () {
    toggleTreeNode($(this));
  });

  $index.on('keydown', '.request-toggle', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleTreeNode($(this));
    }
  });

  // Detail toggle: user clicks the Req # text to open/close the inline
  // detail area (Check In button, etc.). Tracked with is-detail-open so
  // tree collapses can cascade without losing the user's intent.
  function toggleDetail($el) {
    var key = $el.data('detail-target');
    var $detail = $index.find('tr.request-detail[data-detail-of="' + key + '"]');
    $detail.toggleClass('is-detail-open');
    refreshTreeVisibility();
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
  // When a search is active, matching rows and all their ancestors become
  // visible (ancestor toggles flip to expanded). Clearing the search
  // returns the tree to its default collapsed state.
  var $searchInput   = $('#requests-search-input');
  var $searchClear   = $('#requests-search-clear');
  var $searchSummary = $('#requests-search-summary');

  function normalize(s) { return (s || '').toString().toLowerCase(); }

  function applySearch() {
    var q = normalize($searchInput.val()).trim();
    var hasQuery = q.length > 0;
    $searchClear.toggle(hasQuery);

    if (!hasQuery) {
      // Reset: clear search filter, collapse everything, close details,
      // then recompute visibility.
      searchVisibleIds = null;
      $index.find('.request-toggle').attr('aria-expanded', 'false');
      $index.find('tr.request-detail').removeClass('is-detail-open');
      refreshTreeVisibility();
      $searchSummary.text('');
      $('.catalog-section', $index).removeClass('is-empty');
      return;
    }

    // Walk every row and gather the visible set: matches, plus every
    // ancestor of a match (so the tree context stays visible). Expand
    // matching ancestors' toggles so the tree opens up around the match.
    var visibleIds = {};
    var totalMatches = 0;

    $('.catalog-section', $index).each(function () {
      var $section = $(this);
      var sectionMatches = 0;

      $section.find('tr.request-row').each(function () {
        var $row = $(this);
        var text = normalize($row.text());
        if (text.indexOf(q) === -1) return;

        sectionMatches += 1;
        visibleIds[$row.data('parent-key')] = true;

        var attr = String($row.attr('data-ancestors') || '').trim();
        var ancestors = attr.length ? attr.split(/\s+/) : [];
        ancestors.forEach(function (a) {
          visibleIds[a] = true;
          $section.find('.request-toggle[data-target="' + a + '"]').attr('aria-expanded', 'true');
        });
      });

      $section.toggleClass('is-empty', sectionMatches === 0);
      totalMatches += sectionMatches;
    });

    // Close any open detail rows so the search view starts clean, then
    // stash the visible set and let refreshTreeVisibility apply it. Toggle
    // clicks that follow (caret, detail) also call refreshTreeVisibility,
    // so the search filter stays in force through those interactions.
    $index.find('tr.request-detail').removeClass('is-detail-open');
    searchVisibleIds = visibleIds;
    refreshTreeVisibility();

    $searchSummary.text(totalMatches + ' match' + (totalMatches === 1 ? '' : 'es'));
  }

  $searchInput.on('input', applySearch);
  $searchClear.on('click', function () {
    $searchInput.val('').focus();
    applySearch();
  });
});
