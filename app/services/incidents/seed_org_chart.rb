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
        command = find_or_create(kind: :command, name: 'Command', parent: nil)
        SECTIONS.each do |name|
          find_or_create(kind: :section, name: name, parent: nil)
        end

        # Safety Officer is Command Staff, Air is a branch under Operations.
        # These get seeded after their parents exist so the parent_kind
        # validation on OrgUnit is satisfied.
        find_or_create(kind: :branch, name: 'Safety', parent: command)
        operations = @incident.org_units.kind_section.find_by(name: 'Operations')
        find_or_create(kind: :branch, name: 'Air', parent: operations) if operations
      end
      @incident
    end

    private

    def find_or_create(kind:, name:, parent:)
      @incident.org_units.find_or_create_by!(kind: kind, name: name, parent: parent)
    end
  end
end
