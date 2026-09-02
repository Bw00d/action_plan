$(document).on('turbolinks:load', function () {
  var $index = $('.requests-index');
  if (!$index.length) return;

  // Persistent filter state. When any filter (search or status) is active
  // this is an object { rowId: true, ... } listing every row that survives
  // — matches plus their ancestor chain. Null when no filter is active.
  var filterVisibleIds = null;

  // Active status filter set. Empty object = no status filter (show all
  // statuses). Populated by clicking the status filter pills.
  var activeStatuses = {};

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

    var filterActive = filterVisibleIds !== null;

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
        var filterHidden = false;
        if (filterActive) {
          filterHidden = !filterVisibleIds[$row.data('detail-of')];
        }
        $row.toggleClass('is-hidden', !userOpen || ancestorCollapsed || filterHidden);
      } else {
        var filterHiddenRow = false;
        if (filterActive) {
          filterHiddenRow = !filterVisibleIds[$row.data('parent-key')];
        }
        $row.toggleClass('is-hidden', ancestorCollapsed || filterHiddenRow);
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
  // tree collapses can cascade without losing the user's intent. If the
  // row's own caret is currently collapsed, expand it too — otherwise the
  // detail (which lists this row's own row_id as an ancestor) stays hidden
  // by the ancestor-collapse rule.
  function toggleDetail($el) {
    var key = $el.data('detail-target');
    var $detail = $index.find('tr.request-detail[data-detail-of="' + key + '"]');
    var willOpen = !$detail.hasClass('is-detail-open');
    $detail.toggleClass('is-detail-open');
    if (willOpen) {
      $index.find('.request-toggle[data-target="' + key + '"]').attr('aria-expanded', 'true');
    }
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

  // ── Search + status filter ────────────────────────────────────────────
  // A row survives if it matches the search text (if any) AND has one of
  // the active statuses (if any status pill is selected). Matches plus
  // their ancestor chain stay visible so tree context is preserved, and
  // ancestor toggles flip open so the tree expands around each match.
  // Clearing all filters returns the tree to its default collapsed state.
  var $searchInput   = $('#requests-search-input');
  var $searchClear   = $('#requests-search-clear');
  var $searchSummary = $('#requests-search-summary');

  function normalize(s) { return (s || '').toString().toLowerCase(); }

  function applyFilters() {
    var q = normalize($searchInput.val()).trim();
    var hasQuery = q.length > 0;
    var hasStatusFilter = false;
    for (var _k in activeStatuses) { hasStatusFilter = true; break; }
    var hasAnyFilter = hasQuery || hasStatusFilter;

    $searchClear.toggle(hasQuery);

    if (!hasAnyFilter) {
      // Full reset: no filters, collapse everything, close details.
      filterVisibleIds = null;
      $index.find('.request-toggle').attr('aria-expanded', 'false');
      $index.find('tr.request-detail').removeClass('is-detail-open');
      refreshTreeVisibility();
      $searchSummary.text('');
      $('.catalog-section', $index).removeClass('is-empty');
      return;
    }

    var visibleIds = {};
    var totalMatches = 0;

    $('.catalog-section', $index).each(function () {
      var $section = $(this);
      var sectionMatches = 0;

      $section.find('tr.request-row').each(function () {
        var $row = $(this);

        if (hasQuery) {
          var text = normalize($row.text());
          if (text.indexOf(q) === -1) return;
        }

        if (hasStatusFilter) {
          var rowStatus = String($row.attr('data-status') || '');
          if (!activeStatuses[rowStatus]) return;
        }

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

    // Close any open detail rows so the filtered view starts clean, then
    // stash the visible set and let refreshTreeVisibility apply it. Toggle
    // clicks that follow (caret, detail) also call refreshTreeVisibility,
    // so the filters stay in force through those interactions.
    $index.find('tr.request-detail').removeClass('is-detail-open');
    filterVisibleIds = visibleIds;
    refreshTreeVisibility();

    $searchSummary.text(totalMatches + ' match' + (totalMatches === 1 ? '' : 'es'));
  }

  $searchInput.on('input', applyFilters);
  $searchClear.on('click', function () {
    $searchInput.val('').focus();
    applyFilters();
  });

  $index.on('click', '.status-filter', function () {
    var $btn = $(this);
    var status = String($btn.attr('data-status') || '');
    var pressed = $btn.attr('aria-pressed') === 'true';
    $btn.attr('aria-pressed', String(!pressed));
    if (pressed) {
      delete activeStatuses[status];
    } else {
      activeStatuses[status] = true;
    }
    applyFilters();
  });
});
