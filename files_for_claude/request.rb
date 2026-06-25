class Request < ApplicationRecord
  belongs_to :incident

  validates :iroc_req_id, presence: true, uniqueness: true

  # Personnel rows carry name + employment data; resource rows (aircraft,
  # equipment, supply) don't. Catalog name is the cleanest discriminator.
  PERSONNEL_CATALOGS = %w[Overhead Crew].freeze

  scope :personnel, -> { where(req_catalog_name: PERSONNEL_CATALOGS) }
  scope :non_personnel, -> { where.not(req_catalog_name: PERSONNEL_CATALOGS) }
  scope :root_requests, -> { where(root_req_flag: true) }

  # True when this request line represents a named person.
  def person?
    last_name.present?
  end

  # "Last, First Middle" — handy when you later spin up Resource records.
  def full_name
    return res_name unless person?

    [last_name, [first_name, middle_name].compact_blank.join(" ")].compact_blank.join(", ")
  end
end
