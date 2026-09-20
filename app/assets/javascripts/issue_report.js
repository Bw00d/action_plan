// Floating bug icon → modal with the issue report form.
// Loads the form via XHR (issue_reports#new with request.xhr? layout: false)
// so the modal opens instantly without leaving the current page. On submit
// the form posts normally (local: true) and Rails redirects back with a
// flash — simplest path, no client-side error plumbing needed.
$(document).on('turbolinks:load', function () {
  var $btn    = $('#issue-report-btn');
  var $modal  = $('#issue-report-modal');
  if (!$btn.length || !$modal.length) return;

  var $body     = $modal.find('.ir-body');
  var loadedFor = null;   // cache the form HTML across opens on the same page

  function open() {
    var incidentId = $btn.data('incident-id') || '';
    var pageUrl    = window.location.href;

    if (loadedFor !== window.location.pathname) {
      $body.html('<div class="ir-loading">Loading…</div>');
      $.ajax({
        url: '/issue_reports/new',
        method: 'GET',
        dataType: 'html'
      })
        .done(function (html) {
          $body.html(html);
          loadedFor = window.location.pathname;
          $body.find('.ir-incident-id').val(incidentId);
          $body.find('.ir-page-url').val(pageUrl);
          $body.find('input[name="issue_report[title]"]').focus();
        })
        .fail(function (xhr) {
          $body.html('<div class="alert alert-danger">Could not load the form (' + xhr.status + ').</div>');
        });
    } else {
      $body.find('.ir-incident-id').val(incidentId);
      $body.find('.ir-page-url').val(pageUrl);
      $body.find('input[name="issue_report[title]"]').focus();
    }

    $modal.show().attr('aria-hidden', 'false');
    $('body').addClass('ir-modal-open');
  }

  function close() {
    $modal.hide().attr('aria-hidden', 'true');
    $('body').removeClass('ir-modal-open');
  }

  $btn.off('click.issueReport').on('click.issueReport', open);

  // Close on backdrop, × button, cancel button, or Escape.
  $modal.off('click.issueReport').on('click.issueReport', function (e) {
    if ($(e.target).closest('.ir-close, .ir-backdrop, .ir-cancel').length) close();
  });
  $(document).off('keydown.issueReport').on('keydown.issueReport', function (e) {
    if (e.key === 'Escape' && $modal.is(':visible')) close();
  });
});
