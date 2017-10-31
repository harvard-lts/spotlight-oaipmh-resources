require 'spec_helper'
require 'yaml'
include OAI::XPath


  RSpec.describe Spotlight::Resources::OaipmhHarvester, type: :model do
    let(:exhibit) { FactoryGirl.create(:exhibit) }
    subject { described_class.create(exhibit_id: exhibit.id, data: {base_url: 'http://api-qa.lib.harvard.edu:8080/oai', set: 'CNA'}) }

    describe "retrieval" do
          context "given a url and collection" do
            it "finds a list of records" do
              response = subject.oaipmh_harvests
              expect(response).to be_instance_of(OAI::ListRecordsResponse)
              expect(response.entries.size).to be > 0
              expect(response.entries[0]).to be_instance_of(OAI::Record)       
            end
          end
      end
     
  end

