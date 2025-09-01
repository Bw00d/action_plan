$(document).ready(function() {
function adjustFlexRows() {
  const container = $('#print-container');
  container.style.backgroundColor = 'yellow';
  const fixedRows = $('.fixed-height-row');
  const flexRows = $('.flex-row');

  let fixedHeight = 0;
  fixedRows.each(function() {
    fixedHeight += $(this).outerHeight(true);
  });

  const availableHeight = container.height() - fixedHeight;
  const flexRowHeight = availableHeight / flexRows.length;

  flexRows.each(function() {
    $(this).height(flexRowHeight);
  });
}

// Run on load and resize
adjustFlexRows();
$(window).resize(adjustFlexRows);
});