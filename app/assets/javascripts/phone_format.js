// Auto-format phone-number inputs as "(555) 555-1212" while the user
// types. Matches any <input> whose name attribute contains "phone" —
// covers resource.phone, phone_205a_entry.phone_number, the crew-swap
// form's resource_event[phone], etc.
//
// Delegated at the document level so it works for:
//   - static form fields on first render
//   - best_in_place inputs that only exist after a cell is clicked
//   - any future field that follows the "phone" name convention
//
// Non-digit characters typed by the user are ignored — the formatter
// strips, re-formats, and restores the caret based on how many digit
// characters precede it. User can still select-all + paste a raw string
// and it'll be normalized.
(function () {
  function formatDigits(digits) {
    digits = digits.slice(0, 10);
    if (digits.length === 0)      return '';
    if (digits.length < 4)        return '(' + digits;
    if (digits.length < 7)        return '(' + digits.slice(0, 3) + ') ' + digits.slice(3);
    return '(' + digits.slice(0, 3) + ') ' + digits.slice(3, 6) + '-' + digits.slice(6);
  }

  // Count digits in `s` from index 0 up to (but not including) `pos`.
  function digitsBefore(s, pos) {
    var n = 0;
    for (var i = 0; i < pos && i < s.length; i++) if (/\d/.test(s[i])) n++;
    return n;
  }

  // Given the formatted string and a target digit index, find the
  // string position whose caret puts the caret just AFTER that many
  // digits — this is how we restore the user's cursor sensibly.
  function posAfterDigit(s, nDigits) {
    if (nDigits <= 0) return 0;
    var count = 0;
    for (var i = 0; i < s.length; i++) {
      if (/\d/.test(s[i])) {
        count++;
        if (count === nDigits) return i + 1;
      }
    }
    return s.length;
  }

  function reformat(input) {
    var oldVal      = input.value || '';
    var caret       = input.selectionStart || oldVal.length;
    var digitsIndex = digitsBefore(oldVal, caret);
    var digitsOnly  = oldVal.replace(/\D/g, '');
    var newVal      = formatDigits(digitsOnly);
    if (newVal === oldVal) return;
    input.value = newVal;
    try {
      var newCaret = posAfterDigit(newVal, digitsIndex);
      input.setSelectionRange(newCaret, newCaret);
    } catch (e) { /* input types that don't support selection ranges */ }
  }

  function isPhoneInput(el) {
    if (!el || el.tagName !== 'INPUT') return false;
    var type = (el.type || '').toLowerCase();
    if (type && type !== 'text' && type !== 'tel') return false;
    var name = el.getAttribute('name') || '';
    return /phone/i.test(name);
  }

  document.addEventListener('input', function (e) {
    if (!isPhoneInput(e.target)) return;
    reformat(e.target);
  });

  // Normalize once on blur in case the field was pre-populated with a
  // raw string ("5555551212" or "555-555-1212" from an import).
  document.addEventListener('blur', function (e) {
    if (!isPhoneInput(e.target)) return;
    reformat(e.target);
  }, true);  // capture so it fires for best_in_place inputs too
})();
