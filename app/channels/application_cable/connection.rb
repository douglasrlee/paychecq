module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      if set_current_user
        current_user
      else
        reject_unauthorized_connection
      end
    end

    private

    def set_current_user
      session = Session.find_by(id: cookies.signed[:session_id])

      return unless session

      self.current_user = session.user
    end
  end
end
