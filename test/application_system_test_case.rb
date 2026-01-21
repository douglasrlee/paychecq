require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if RUBY_PLATFORM.include?('darwin')
    driven_by :selenium, using: :safari
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_option|
      driver_option.add_argument('--no-sandbox')
      driver_option.add_argument('--disable-dev-shm-usage')
      driver_option.add_argument('--disable-gpu')
      driver_option.add_argument('--headless=new')

      # WSL uses snap chromium at a different path
      if File.exist?('/usr/bin/chromium-browser')
        driver_option.add_argument('--remote-debugging-port=9222')
        driver_option.add_argument('--disable-software-rasterizer')
        driver_option.binary = '/usr/bin/chromium-browser'
      end
    end
  end
end
