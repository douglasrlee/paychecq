# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :confirmable, :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later(retry_on: RuntimeError, wait: 5.seconds, attempts: :unlimited)
  end
end
