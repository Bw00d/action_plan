// ICS 205A phone list — drag-to-reorder rows within a section card.
// Grab the ⠿ handle on the left of a row and drop it where you want it.
// After the drop we POST the new ordered id list back to the server
// which rewrites sort_order on each row in that section.
$(document).on('turbolinks:load', function () {
  var $grid = $('.phone-205a-grid');
  if (!$grid.length) return;

  var sortUrl = $grid.data('sort-url');
  var csrfToken = $('meta[name=csrf-token]').attr('content');

  $grid.find('.phone-205a-card').each(function () {
    var $card    = $(this);
    var section  = $card.data('section');
    var $tbody   = $card.find('.phone-205a-table tbody');
    if (!$tbody.length) return;

    $tbody.sortable({
      handle: '.col-drag',
      items:  '> tr',
      axis:   'y',
      tolerance: 'pointer',
      // Preserve column widths while the row is being dragged — without
      // this the clone collapses to text width and looks jarring.
      helper: function (e, tr) {
        var $originals = tr.children();
        var $helper = tr.clone();
        $helper.children().each(function (i) {
          $(this).width($originals.eq(i).outerWidth());
        });
        return $helper;
      },
      update: function () {
        var orderedIds = $tbody.children('tr').map(function () {
          return $(this).data('entry-id');
        }).get();
        $.ajax({
          url:    sortUrl,
          method: 'PATCH',
          data:   { section: section, ordered_ids: orderedIds },
          headers: { 'X-CSRF-Token': csrfToken }
        });
      }
    }).disableSelection();
  });
});
