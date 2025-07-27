require 'rails_helper'

RSpec.describe Plan, type: :model do
  # Associations
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:incident) }
    it { should have_many(:assignments).dependent(:destroy) }
    it { should have_many(:objectives).dependent(:destroy) }
    it { should have_many(:activities).dependent(:destroy) }
    it { should have_many(:teams).dependent(:destroy) }
    it { should have_many(:attachments).dependent(:destroy) }
    it { should have_one(:commo_plan) }
    it { should have_one(:safety_message) }
    it { should have_one(:cover) }
  end

  # Validations
  describe 'validations' do
    
    describe 'uniqueness of date' do
      let(:incident) { create(:incident) }
      let!(:existing_plan) { create(:plan, incident: incident, date: Date.today) }
      
      it 'validates uniqueness of date scoped to incident' do
        new_plan = build(:plan, incident: incident, date: Date.today)
        expect(new_plan).not_to be_valid
        expect(new_plan.errors[:date]).to include('has already been taken')
      end
      
      it 'allows same date for different incidents' do
        other_incident = create(:incident)
        new_plan = build(:plan, incident: other_incident, date: Date.today)
        expect(new_plan).to be_valid
      end
    end
  end

  # Callbacks
  describe 'callbacks' do
    describe 'after_create' do
      context 'when incident has no previous plans' do
        let(:incident) { create(:incident) }
        let(:plan) { build(:plan, incident: incident) }
        
        it 'creates default attachments' do
          expect { plan.save }.to change(Attachment, :count).by(12)
        end
        
        it 'does not duplicate from previous plans' do
          expect(plan).not_to receive(:duplicate_objectives)
          expect(plan).not_to receive(:duplicate_teams)
          expect(plan).not_to receive(:duplicate_assignments)
          expect(plan).not_to receive(:duplicate_commo_plan)
          expect(plan).not_to receive(:duplicate_safety_message)
          plan.save
        end
      end
      
      context 'when incident has previous plans' do
        let(:incident) { create(:incident) }
        let!(:first_plan) { create(:plan, incident: incident, date: 1.day.ago) }
        let!(:objective) { create(:objective, plan: first_plan, description: 'Test objective') }
        let!(:team) { create(:team, plan: first_plan, staff: 'Command') }
        let!(:assignment) { create(:assignment, plan: first_plan) }
        let!(:commo_plan) { create(:commo_plan, plan: first_plan) }
        let!(:commo_item) { create(:commo_item, commo_plan: commo_plan) }
        let!(:safety_message) { create(:safety_message, plan: first_plan, hazards: 'Test hazards') }
        
        let(:new_plan) { build(:plan, incident: incident, date: Date.today) }
        
        it 'duplicates objectives' do
          expect { new_plan.save }.to change(Objective, :count).by(1)
          expect(new_plan.objectives.first.description).to eq('Test objective')
        end
        
        it 'duplicates teams' do
          expect { new_plan.save }.to change(Team, :count).by(1)
          expect(new_plan.teams.first.staff).to eq('Command')
        end
        
        it 'duplicates assignments' do
          expect { new_plan.save }.to change(Assignment, :count).by(1)
        end
        
        it 'duplicates commo plan and items' do
          new_plan = build(:plan, incident: incident, date: Date.today)
          # Save the plan first
          new_plan.save!

          expect(new_plan.commo_plan).to be_present
          expect(new_plan.commo_plan.commo_items.count).to eq(1)

          expect(new_plan.commo_plan.ops_period).to eq(first_plan.commo_plan.ops_period)
        end
        
        it 'duplicates safety message' do
          expect { new_plan.save }.to change(SafetyMessage, :count).by(1)
          expect(new_plan.safety_message.hazards).to eq('Test hazards')
        end
      end
    end
  end

  # Instance methods
  describe '#command_staff' do
    let(:plan) { create(:plan) }
    let!(:command_team) { create(:team, plan: plan, staff: 'Command') }
    let!(:other_team) { create(:team, plan: plan, staff: 'Operations') }
    
    it 'returns only command staff teams' do
      expect(plan.command_staff).to contain_exactly(command_team)
    end
  end

  describe '#agency_reps' do
    let(:plan) { create(:plan) }
    let!(:agency_team) { create(:team, plan: plan, staff: 'Agency') }
    let!(:other_team) { create(:team, plan: plan, staff: 'Command') }
    
    it 'returns only agency teams' do
      expect(plan.agency_reps).to contain_exactly(agency_team)
    end
  end

  describe '#plans' do
    let(:plan) { create(:plan) }
    let!(:plans_team) { create(:team, plan: plan, staff: 'Plans') }
    let!(:other_team) { create(:team, plan: plan, staff: 'Command') }
    
    it 'returns only plans teams' do
      expect(plan.plans).to contain_exactly(plans_team)
    end
  end

  describe '#finance' do
    let(:plan) { create(:plan) }
    let!(:finance_team) { create(:team, plan: plan, staff: 'Finance') }
    let!(:other_team) { create(:team, plan: plan, staff: 'Command') }
    
    it 'returns only finance teams' do
      expect(plan.finance).to contain_exactly(finance_team)
    end
  end

  describe '#operations' do
    let(:plan) { create(:plan) }
    let!(:ops_team) { create(:team, plan: plan, staff: 'Operations') }
    let!(:other_team) { create(:team, plan: plan, staff: 'Command') }
    
    it 'returns only operations teams' do
      expect(plan.operations).to contain_exactly(ops_team)
    end
  end

  describe '#logistics' do
    let(:plan) { create(:plan) }
    let!(:logistics_team) { create(:team, plan: plan, staff: 'Logistics') }
    let!(:other_team) { create(:team, plan: plan, staff: 'Command') }
    
    it 'returns only logistics teams' do
      expect(plan.logistics).to contain_exactly(logistics_team)
    end
  end

  describe '#add_attachments' do
    let(:plan) { create(:plan) }
    
    it 'creates 12 default attachments' do
      # Already created by callback, so let's check they exist
      expect(plan.attachments.count).to eq(12)
      expect(plan.attachments.pluck(:description)).to include(
        "ORGANIZATION LIST", 
        "ASSIGNMENT LIST", 
        "COMMUNITCATIONS PLAN",
        "MEDICAL PLAN",
        "FINANCE MESSAGE",
        "INCIDENT MAP",
        "TRAFFIC PLAN"
      )
    end
  end
end