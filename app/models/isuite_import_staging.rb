# Short-lived cache of an uploaded e-iSuite CSV between the preview and
# apply steps of the import flow. Backed by Postgres so it survives dyno
# restarts and works across multiple web processes (Rails.cache with the
# default file/memory store does neither reliably on Heroku).
class IsuiteImportStaging < ApplicationRecord
  belongs_to :incident
  belongs_to :user, optional: true

  TTL = 30.minutes

  def self.stash(incident:, user:, csv_data:)
    create!(
      token:      SecureRandom.hex(16),
      incident:   incident,
      user:       user,
      csv_data:   csv_data,
      expires_at: TTL.from_now
    )
  end

  def self.find_active(token)
    where("expires_at > ?", Time.current).find_by(token: token)
  end

  def self.sweep_expired!
    where("expires_at <= ?", Time.current).delete_all
  end
end
