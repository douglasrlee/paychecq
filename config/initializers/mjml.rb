# frozen_string_literal: true

Mjml.setup do |config|
  config.template_language = :erb
  config.raise_render_exception = true
  config.beautify = false
  config.minify = true
  config.validation_level = 'strict'
  config.use_mrml = false
  config.mjml_binary = nil
  config.mjml_binary_version_supported = '4.'
  config.fonts = { Roboto: 'https://fonts.googleapis.com/css2?family=Roboto:ital,wght@0,100;0,300;0,400;0,500;0,700;0,900;1,100;1,300;1,400;1,500;1,700;1,900' }
end
