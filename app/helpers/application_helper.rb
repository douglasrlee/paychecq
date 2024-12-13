# frozen_string_literal: true

module ApplicationHelper
  def gravatar_url
    email = current_user.email.downcase
    hash = Digest::SHA256.hexdigest(email)
    default = 'mp'
    size = 35
    params = URI.encode_www_form('d' => default, 's' => size)
    "https://www.gravatar.com/avatar/#{hash}?#{params}"
  end
end
