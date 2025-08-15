Grover.configure do |config|
  config.options = {
    format: 'Letter',
    margin: {
      top: '0',
      bottom: '0',
      left: '0',
      right: '0'
    },
    display_header_footer: false,
    prefer_css_page_size: true,
    cache: false,
    timeout: 30000, # Timeout in ms
    launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--font-render-hinting=medium'],
    wait_until: 'networkidle0',
    print_background: true,
    emulate_media: 'print',
    viewport: {
      width: 816,  # 8.5" at 96dpi
      height: 1056 # 11" at 96dpi
    },
    scale: 1.0
  }
end