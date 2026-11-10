require 'rails_helper'

RSpec.describe DemobNotification, type: :model do
  describe '.from_demob unit_id' do
    let(:resource) { create(:resource, agency: 'USFS', order_number: '12', category: 'OVERHEAD') }
    let(:incident) { resource.incident }

    def notify(demob)
      demob.update!(actual_release_date: Date.current)
      described_class.find_by!(demob_id: demob.id)
    end

    it 'uses the unit half of the IROC provider' do
      incident.requests.create!(iroc_req_id: 'IROC-O-12', req_number: 'O-12', req_catalog_name: 'Overhead',
                                res_prov_agency_abbrev: 'USFS', res_prov_unit_code: 'OR-MHF')
      expect(notify(resource.demob).unit_id).to eq('OR-MHF')
    end

    it 'falls back to agency without an imported request' do
      expect(notify(resource.demob).unit_id).to eq('USFS')
    end

    it "uses a subordinate's own request" do
      incident.requests.create!(iroc_req_id: 'IROC-O-12.3', req_number: 'O-12.3', req_catalog_name: 'Overhead',
                                res_prov_agency_abbrev: 'USFS', res_prov_unit_code: 'OR-UMF')
      roster = resource.rosters.create!(name: 'Doe, Jane', order_number: '3')
      expect(notify(roster.demob_or_create).unit_id).to eq('OR-UMF')
    end
  end
end
