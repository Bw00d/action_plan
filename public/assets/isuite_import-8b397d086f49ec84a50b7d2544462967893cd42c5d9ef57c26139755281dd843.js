// Select-all master checkboxes on the iSuite import preview.
// Each master has data-target=".css-selector-for-row-checkboxes" and
// toggles every matching checkbox inside its section.
$(document).on('turbolinks:load', function () {
  $(document).off('change.iiSelectAll').on('change.iiSelectAll', '.ii-select-all', function () {
    var selector = $(this).data('target');
    if (!selector) return;
    var checked = this.checked;
    // Skip disabled boxes (like the "always create" new-row ones).
    $(this).closest('.ii-section').find(selector).each(function () {
      if (this.disabled) return;
      this.checked = checked;
    });
  });

  // Reverse: unchecking any row checkbox unticks the master; checking
  // all row checkboxes ticks it. Keeps the header in sync with state.
  $(document).off('change.iiRowSync').on('change.iiRowSync', '.ii-resource-check, .ii-roster-check', function () {
    var $section = $(this).closest('.ii-section');
    var selectorClass = $(this).hasClass('ii-resource-check') ? '.ii-resource-check' : '.ii-roster-check';
    var $rows = $section.find(selectorClass).not(':disabled');
    var allChecked = $rows.length > 0 && $rows.filter(':not(:checked)').length === 0;
    $section.find('.ii-select-all').prop('checked', allChecked);
  });
});
