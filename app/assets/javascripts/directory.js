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

// Phone fields on the profile form: tidy to "(541) 555-0123" when the user
// leaves the field. Same rules as app/services/phone_number.rb, which also
// formats on save; anything that isn't a 10-digit US number is left alone.
// data-phone-format="when-phone" only formats while the form's kind select
// is set to Phone (the contact field takes emails too).
(function () {
  function formatPhone(raw) {
    var value = $.trim(raw || '');
    if (!value) return value;
    var ext = null;
    var m = value.match(/\s*(?:x|ext\.?|extension|#)\s*(\d+)\s*$/i);
    var main = value;
    if (m) { ext = m[1]; main = value.slice(0, m.index); }
    var digits = main.replace(/\D/g, '');
    if (digits.length === 11 && digits.charAt(0) === '1') digits = digits.slice(1);
    if (digits.length !== 10) return value;
    var formatted = '(' + digits.slice(0, 3) + ') ' + digits.slice(3, 6) + '-' + digits.slice(6);
    return ext ? formatted + ' ext. ' + ext : formatted;
  }

  $(document).on('blur', 'input[data-phone-format]', function () {
    var $input = $(this);
    if ($input.data('phone-format') === 'when-phone' &&
        $input.closest('form').find('select[name$="[kind]"]').val() !== 'phone') return;
    $input.val(formatPhone($input.val()));
  });
})();
