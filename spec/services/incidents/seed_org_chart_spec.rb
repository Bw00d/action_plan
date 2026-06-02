require 'rails_helper'

RSpec.describe Incidents::SeedOrgChart do
  let(:incident) { create(:incident) }

  it 'creates Command plus the four ICS sections' do
    described_class.call(incident)

    kinds_by_name = incident.org_units.pluck(:name, :kind).to_h
    expect(kinds_by_name).to eq(
      'Command'    => 'command',
      'Operations' => 'section',
      'Plans'      => 'section',
      'Logistics'  => 'section',
      'Finance'    => 'section'
    )
  end

  it 'is idempotent' do
    described_class.call(incident)
    expect { described_class.call(incident) }.not_to change { incident.org_units.count }
  end

  it 'returns the incident' do
    expect(described_class.call(incident)).to eq(incident)
  end
end
