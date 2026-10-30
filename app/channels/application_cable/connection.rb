# :nocov:
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # Reuse the Devise session cookie — signed-out sockets are refused.
    def connect
      self.current_user = env['warden']&.user || reject_unauthorized_connection
    end
  end
end
# :nocov:
