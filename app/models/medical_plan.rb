class MedicalPlan < ApplicationRecord
  belongs_to :plan
  has_many :medical_ambulances,     -> { order(:position, :id) }, dependent: :destroy
  has_many :medical_air_ambulances, -> { order(:position, :id) }, dependent: :destroy
  has_many :medical_hospitals,      -> { order(:position, :id) }, dependent: :destroy
  has_many :medical_zones,          -> { order(:position, :id) }, dependent: :destroy

  # Convenience partitions for the two 6/7 flavors sharing a table.
  def medical_divisions
    medical_zones.select(&:division?)
  end

  def medical_camps
    medical_zones.select(&:camp?)
  end
end
