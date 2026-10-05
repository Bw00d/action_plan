(function () {
  function init() {
    var page = document.querySelector('.board-page');
    if (!page) return;

    var incidentId = page.dataset.incidentId;
    var moveUrl = '/incidents/' + incidentId + '/board/move';
    var csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    function recomputePersonnel() {
      $('.board-column', page).each(function () {
        var $col = $(this);
        var total = 0;
        $col.find('.board-card').each(function () {
          total += parseInt($(this).data('personnel'), 10) || 0;
        });
        var $badge = $col.find('.board-column-personnel');
        $badge.find('.board-column-personnel-count').text(total);
        $badge.toggleClass('is-empty', total === 0);
      });
    }

    $('.board-cards').sortable({
      connectWith: '.board-cards',
      placeholder: 'board-card-placeholder',
      forcePlaceholderSize: true,
      tolerance: 'pointer',
      cursor: 'grabbing',
      distance: 6,
      cancel: '.board-card-details, .board-card-move-toggle, .board-card-move-menu, .best_in_place, input, textarea, select, button, a',
      update: function (event, ui) {
        // Only fire on the receiving list to avoid two calls per drop
        if (this !== ui.item.parent()[0]) return;

        var resourceId = ui.item.data('resource-id');
        var column = ui.item.closest('.board-column');
        var orgUnitId = column.data('org-unit-id');
        var position = column.find('.board-card').index(ui.item) + 1;

        var $sortable = $('.board-cards').sortable('disable');
        recomputePersonnel();

        $.ajax({
          url: moveUrl,
          method: 'PATCH',
          data: {
            resource_id: resourceId,
            org_unit_id: orgUnitId === '' ? null : orgUnitId,
            position: position
          },
          headers: { 'X-CSRF-Token': csrfToken }
        })
          .fail(function () {
            $(event.target).sortable('cancel');
            recomputePersonnel();
            alert('Move failed. Refresh the page.');
          })
          .always(function () {
            $sortable.sortable('enable');
          });
      }
    }).disableSelection();

    $(page).on('click', '.board-add-child-toggle', function () {
      var $wrapper = $(this).closest('.board-add-child');
      $wrapper.find('.board-add-child-form').toggle();
    });

    $(page).on('click', '.board-add-child-cancel', function () {
      $(this).closest('.board-add-child-form').hide();
    });

    // --- Header "+ New Column" opener/closer -----------------------------
    $(page).on('click', '.board-new-column-toggle', function () {
      $(this).closest('.board-new-column').find('.board-new-column-form').toggle();
    });
    $(page).on('click', '.board-new-column-cancel', function () {
      $(this).closest('.board-new-column-form').hide();
    });

    // --- Board search (live client-side filter + jump-to-match) ----------
    // Highlights every matching card without hiding its neighbors, so the
    // user keeps their sense of position. The current match is scrolled
    // into view (horizontally + vertically) and marked with a stronger
    // "current" ring. Prev/Next buttons + Enter / Shift+Enter in the
    // input cycle through all matches.
    var searchInput  = document.getElementById('board-search-input');
    var searchClear  = document.getElementById('board-search-clear');
    var searchCount  = document.getElementById('board-search-count');
    var searchPrev   = document.getElementById('board-search-prev');
    var searchNext   = document.getElementById('board-search-next');

    var matchEls   = [];   // array of matching card nodes in DOM order
    var matchIndex = 0;

    function cardSearchText(card) {
      var cached = card.getAttribute('data-search-text');
      if (cached != null) return cached;
      var text = (card.textContent || '').toLowerCase().replace(/\s+/g, ' ').trim();
      card.setAttribute('data-search-text', text);
      return text;
    }

    function clearCurrentMarker() {
      page.querySelectorAll('.board-card--current').forEach(function (c) {
        c.classList.remove('board-card--current');
      });
    }

    function focusCurrent() {
      clearCurrentMarker();
      if (!matchEls.length) {
        if (searchCount) searchCount.textContent = searchInput.value ? '0 matches' : '';
        return;
      }
      // Wrap on overflow in either direction.
      if (matchIndex < 0) matchIndex = matchEls.length - 1;
      if (matchIndex >= matchEls.length) matchIndex = 0;
      var el = matchEls[matchIndex];
      el.classList.add('board-card--current');
      // scrollIntoView walks every scrollable ancestor — handles the
      // horizontal .board-columns scroll + the vertical .board-cards
      // scroll together.
      el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'smooth' });
      if (searchCount) {
        searchCount.textContent = (matchIndex + 1) + ' of ' + matchEls.length;
      }
    }

    function applyBoardSearch() {
      if (!searchInput) return;
      var q = searchInput.value.toLowerCase().trim();
      var cards = page.querySelectorAll('.board-card');
      matchEls = [];
      cards.forEach(function (card) {
        if (card.classList.contains('board-card--spacer')) {
          card.classList.remove('board-card--match');
          return;
        }
        if (q && cardSearchText(card).indexOf(q) >= 0) {
          card.classList.add('board-card--match');
          matchEls.push(card);
        } else {
          card.classList.remove('board-card--match');
        }
      });
      page.classList.toggle('board-search-active', !!q);
      matchIndex = 0;
      if (q) {
        focusCurrent();
      } else {
        clearCurrentMarker();
        if (searchCount) searchCount.textContent = '';
      }
    }

    function stepMatch(delta) {
      if (!matchEls.length) return;
      matchIndex += delta;
      focusCurrent();
    }

    if (searchInput) {
      searchInput.addEventListener('input', applyBoardSearch);
      searchInput.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { this.value = ''; applyBoardSearch(); return; }
        if (e.key === 'Enter') {
          e.preventDefault();
          stepMatch(e.shiftKey ? -1 : 1);
        }
      });
    }
    if (searchClear && searchInput) {
      searchClear.addEventListener('click', function () {
        searchInput.value = '';
        applyBoardSearch();
        searchInput.focus();
      });
    }
    if (searchPrev) searchPrev.addEventListener('click', function () { stepMatch(-1); });
    if (searchNext) searchNext.addEventListener('click', function () { stepMatch(1);  });

    // --- Trello-style expanded card modal -------------------------------
    // Double-click a card to pull its details into a fixed, centered
    // modal with a dimmed backdrop. Close via the X, backdrop click, or
    // Escape key. Only one card can be expanded at a time.
    var $overlay = $('#board-card-overlay');

    function closeExpandedCard() {
      $('.board-card.is-expanded', page).removeClass('is-expanded');
      $overlay.removeClass('is-visible');
    }

    $(page).on('dblclick', '.board-card', function (e) {
      if ($(e.target).closest('.board-card-details, .board-card-actions').length > 0) return;
      var $card = $(this);
      var wasExpanded = $card.hasClass('is-expanded');
      closeExpandedCard();
      // Clear any active search before expanding — the search-active
      // dim rule (opacity: 0.25) also dims the modal content inside the
      // card, which makes editing basically unreadable. User's done
      // finding the card; drop the filter so they can work on it.
      if (searchInput && searchInput.value) {
        searchInput.value = '';
        applyBoardSearch();
      }
      if (!wasExpanded) {
        $card.addClass('is-expanded');
        $overlay.addClass('is-visible');
      }
    });

    $(page).on('click', '.board-card-details-close', function (e) {
      e.stopPropagation();
      closeExpandedCard();
    });

    $overlay.on('click', closeExpandedCard);

    $(document).on('keydown.boardCardModal', function (e) {
      if (e.key === 'Escape' && $('.board-card.is-expanded', page).length) {
        closeExpandedCard();
      }
    });

    // --- Live LWD recalc on the expanded card ------------------------------
    // LWD = FWD + assignment_length - 1 day. We update it on the fly as the
    // user edits either input, before best_in_place's AJAX save returns —
    // the user wants instant feedback, not a server round-trip wait.
    //
    // Last-known-good values are mirrored to data-fwd / data-assignment-length
    // on the <li>; this lets a change to just one field reliably pick up the
    // OTHER field's value without having to parse best_in_place's rendered
    // display text (which can vary by Rails format config).
    function parseFlexibleDate(s) {
      if (s == null) return null;
      s = String(s).trim();
      if (!s) return null;
      var m;
      // ISO: YYYY-MM-DD(THH:MM...) — handles both bare dates and full ISO
      m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
      if (m) return new Date(+m[1], +m[2] - 1, +m[3]);
      // US: M/D/YYYY or M/D/YY or M/D (current year)
      m = s.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
      if (m) {
        var year = m[3] ? +m[3] : new Date().getFullYear();
        if (year < 100) year += 2000;
        return new Date(year, +m[1] - 1, +m[2]);
      }
      var d = new Date(s);
      return isNaN(d.getTime()) ? null : d;
    }

    // MM/DD/YY — matches the LWD format used elsewhere in the app.
    function fmtShortDate(d) {
      var y = String(d.getFullYear()).slice(-2);
      var m = String(d.getMonth() + 1).padStart(2, '0');
      var dd = String(d.getDate()).padStart(2, '0');
      return m + '/' + dd + '/' + y;
    }

    function recalcLwd($card) {
      var fwdStr    = String($card.attr('data-fwd') || '').trim();
      var lengthStr = String($card.attr('data-assignment-length') || '').trim();
      var fwd       = parseFlexibleDate(fwdStr);
      var length    = parseInt(lengthStr, 10);
      var $lwdCell  = $card.find('[data-field="lwd"]');
      if (!fwd || isNaN(length) || length < 1) {
        $lwdCell.text('—');
        return;
      }
      var lwd = new Date(fwd.getFullYear(), fwd.getMonth(), fwd.getDate() + length - 1);
      $lwdCell.text(fmtShortDate(lwd));
    }

    // Keep the <li> data-* attrs in sync with whatever the user types.
    // 'input' fires on every keystroke (instant feedback), 'change' catches
    // paste / autofill, 'best_in_place:success' catches the final
    // server-normalized value in case we parsed something unusual.
    function stashFromInput(input, cardAttr) {
      var $card = $(input).closest('.board-card');
      $card.attr(cardAttr, $(input).val());
      recalcLwd($card);
    }

    $(page).on('input change blur',
      '[data-field="fwd"] input', function () { stashFromInput(this, 'data-fwd'); });

    $(page).on('input change blur',
      '[data-field="assignment_length"] input', function () { stashFromInput(this, 'data-assignment-length'); });

    $(page).on('best_in_place:success', '[data-field="fwd"] .best_in_place', function () {
      var $card = $(this).closest('.board-card');
      $card.attr('data-fwd', $(this).text().trim());
      recalcLwd($card);
    });

    $(page).on('best_in_place:success', '[data-field="assignment_length"] .best_in_place', function () {
      var $card = $(this).closest('.board-card');
      $card.attr('data-assignment-length', $(this).text().trim());
      recalcLwd($card);
    });

    // --- Hover move affordance --------------------------------------------
    // Build the target list from the DOM at click time so it reflects any
    // columns that were just added/deleted without a page reload.
    function buildMoveMenu($menu, currentOrgUnitId) {
      var $list = $menu.find('.board-card-move-menu-list').empty();
      $('.board-column', page).each(function () {
        var $col = $(this);
        var orgUnitId = String($col.data('org-unit-id') || '');
        if (orgUnitId === String(currentOrgUnitId || '')) return; // skip current
        var label = $col.find('.board-column-title').first().text().trim();
        var subtitle = $col.find('.board-column-subtitle').first().text().trim();
        var display = subtitle ? subtitle + ' — ' + label : label;
        $list.append(
          $('<li>').addClass('board-card-move-menu-item')
                   .attr('data-target-org-unit-id', orgUnitId)
                   .text(display || 'Unassigned')
        );
      });
    }

    $(page).on('click', '.board-card-move-toggle', function (e) {
      e.stopPropagation();
      var $card = $(this).closest('.board-card');
      // Scope to the toggle's own parent — the modal header has its
      // own MOVE button + menu pair separate from the small-strip one.
      var $menu = $(this).parent().find('.board-card-move-menu').first();
      var currentOrgUnitId = $card.closest('.board-column').data('org-unit-id') || '';
      $('.board-card-move-menu').not($menu).hide();
      if ($menu.is(':visible')) { $menu.hide(); return; }
      buildMoveMenu($menu, currentOrgUnitId);
      $menu.show();
    });

    $(page).on('click', '.board-card-move-menu-item', function (e) {
      e.stopPropagation();
      var $item = $(this);
      var targetOrgUnitId = String($item.data('target-org-unit-id') || '');
      var $card = $item.closest('.board-card');
      var resourceId = $card.data('resource-id');
      var $target = $('.board-column[data-org-unit-id="' + targetOrgUnitId + '"] .board-cards', page);

      $.ajax({
        url: moveUrl,
        method: 'PATCH',
        data: {
          resource_id: resourceId,
          org_unit_id: targetOrgUnitId === '' ? null : targetOrgUnitId,
          position: $target.children('.board-card').length + 1
        },
        headers: { 'X-CSRF-Token': csrfToken }
      })
        .done(function () {
          $card.find('.board-card-move-menu').hide();
          $card.appendTo($target);
          recomputePersonnel();
        })
        .fail(function () { alert('Move failed. Refresh the page.'); });
    });

    // Click outside closes any open menu.
    $(document).on('click.boardMoveMenu', function () {
      $('.board-card-move-menu', page).hide();
    });

    // --- Blank-row (spacer) create/delete ---------------------------------
    $(page).on('click', '.board-add-spacer', function () {
      var $btn = $(this);
      if ($btn.prop('disabled')) return;
      $btn.prop('disabled', true);

      $.ajax({
        url: $btn.data('url'),
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        dataType: 'html'
      })
        .done(function (html) {
          var $target = $('#unassigned .board-cards', page);
          $target.prepend(html);
          recomputePersonnel();
        })
        .fail(function () { alert('Could not add blank row. Refresh the page.'); })
        .always(function () { $btn.prop('disabled', false); });
    });

    $(page).on('click', '.board-card-delete-spacer', function (e) {
      e.stopPropagation();
      var $btn = $(this);
      var $card = $btn.closest('.board-card');

      $.ajax({
        url: $btn.data('url'),
        method: 'DELETE',
        headers: { 'X-CSRF-Token': csrfToken }
      })
        .done(function () {
          $card.remove();
          recomputePersonnel();
        })
        .fail(function () { alert('Could not delete blank row. Refresh the page.'); });
    });
  }

  $(document).on('turbolinks:load', init);
})();
