# PNG QR code for a public link (remote check-in / remote demob), for
# the Plans section to print or post. Generated on request from the
# current URL, so a rotated token gets a fresh code.
class LinkQrCode
  # 600px is large enough to print at a few inches and still scan.
  def self.png(url, size: 600)
    RQRCode::QRCode.new(url).as_png(size: size, border_modules: 4).to_s
  end
end
