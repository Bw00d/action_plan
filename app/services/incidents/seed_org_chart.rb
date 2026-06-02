module Incidents
  class SeedOrgChart
    SECTIONS = %w[Operations Plans Logistics Finance].freeze

    def self.call(incident)
      new(incident).call
    end

    def initialize(incident)
      @incident = incident
    end

    def call
      ActiveRecord::Base.transaction do
        find_or_create(kind: :command, name: 'Command', parent: nil)
        SECTIONS.each do |name|
          find_or_create(kind: :section, name: name, parent: nil)
        end
      end
      @incident
    end

    private

    def find_or_create(kind:, name:, parent:)
      @incident.org_units.find_or_create_by!(kind: kind, name: name, parent: parent)
    end
  end
end
