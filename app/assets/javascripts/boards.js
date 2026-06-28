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
      cancel: '.board-card-details, .best_in_place, input, textarea, select, button, a',
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
  }

  $(document).on('turbolinks:load', init);
})();
