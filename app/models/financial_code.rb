class FinancialCode < ApplicationRecord
  belongs_to :incident

  validates :agency, :code, presence: true
  # One entry per agency per incident. Users can update the code value in
  # place, or delete + re-add if the agency really needs to change.
  validates :agency, uniqueness: { scope: :incident_id, case_sensitive: false,
                                    message: "already exists for this incident" }

  default_scope -> { order(:position, :id) }

  before_validation :normalize_agency

  private

  def normalize_agency
    self.agency = agency.to_s.strip.upcase if agency.present?
  end
end
