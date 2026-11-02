// Directory profile: the Phone and Email buttons reveal the shared numbers
// and addresses on the page instead of opening the phone or mail app.
$(document).on('turbolinks:load', function () {
  $('.dir-profile').off('click.dirContact').on('click.dirContact', '[data-contact-toggle]', function () {
    var $btn = $(this);
    var $panel = $('#' + $btn.attr('aria-controls'));
    var open = $btn.attr('aria-expanded') !== 'true';
    $btn.attr('aria-expanded', String(open)).toggleClass('active', open);
    $panel.prop('hidden', !open);
  });
});
