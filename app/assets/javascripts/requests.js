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
});
