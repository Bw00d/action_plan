# An NWCG position (e.g. OSC2 · Operations Section Chief Type 2) that a
# User can hold as a Qualification. The catalog lives in
# config/positions.yml; load it with `rails positions:load`.
class Position < ApplicationRecord
  CATALOG_PATH = Rails.root.join('config', 'positions.yml')

  has_many :qualifications, dependent: :restrict_with_exception

  before_validation { self.code = code.to_s.strip.upcase }

  validates :code, presence: true, uniqueness: true
  validates :title, presence: true

  scope :alphabetical, -> { order(:code) }

  # Adds new codes and updates titles; never deletes, since users may
  # already hold a position that's later dropped from the file.
  def self.load_catalog!
    YAML.load_file(CATALOG_PATH).each do |code, title|
      find_or_initialize_by(code: code.to_s.upcase).update!(title: title)
    end
  end

  def label
    "#{code} · #{title}"
  end
end
