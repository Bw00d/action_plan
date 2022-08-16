Grover.configure do |config|
  config.options = {
    format: 'A4',
    margin: {
      top: '0',
      bottom: '0'
    },
    display_url: "http://localhost:3000",
    display_header_footer: false,
    prefer_css_page_size: true,
    cache: false,
    timeout: 0, # Timeout in ms. A value of `0` means 'no timeout'
    launch_args: ['--font-render-hinting=medium'],
    wait_until: 'domcontentloaded'
  }
end