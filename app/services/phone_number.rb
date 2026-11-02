# Formats North American phone numbers as "(541) 555-0123", keeping an
# extension ("ext. 12"). Anything else (international, satellite, too
# short) is returned as typed so it's never mangled. Mirrored in
# directory.js for formatting as the user types.
module PhoneNumber
  EXTENSION = /\s*(?:x|ext\.?|extension|#)\s*(\d+)\s*\z/i

  module_function

  def format(raw)
    value = raw.to_s.strip
    return value if value.empty?

    main, ext = value.match(EXTENSION) ? [value.sub(EXTENSION, ''), Regexp.last_match(1)] : [value, nil]
    digits = main.gsub(/\D/, '')
    digits = digits[1..] if digits.length == 11 && digits.start_with?('1') # US country code
    return value unless digits.length == 10

    formatted = "(#{digits[0, 3]}) #{digits[3, 3]}-#{digits[6, 4]}"
    ext ? "#{formatted} ext. #{ext}" : formatted
  end
end
