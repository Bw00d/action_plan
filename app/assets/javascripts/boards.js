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

    $(page).on('dblclick', '.board-card', function (e) {
      if ($(e.target).closest('.board-card-details').length > 0) return;
      $(this).find('.board-card-details').toggle();
    });

    $(page).on('click', '.board-card-details-close', function (e) {
      e.stopPropagation();
      $(this).closest('.board-card-details').hide();
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
      var $menu = $card.find('.board-card-move-menu');
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
  }

  $(document).on('turbolinks:load', init);
})();
