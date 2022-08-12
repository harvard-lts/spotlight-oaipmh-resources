require 'spec_helper'


  RSpec.describe Spotlight::Resources::OaipmhModsParser, type: :model do
    let(:exhibit) { FactoryGirl.create(:exhibit) }
    let(:converter) { Spotlight::Resources::OaipmhModsConverter.new('CNA', 'test-exhibit-name')}
    subject { described_class.new(exhibit, converter) }

      describe "fetch_ids_uri" do
          context "given a url with a urn-3" do
            it "returns the resolving ids url" do
                uri = subject.fetch_ids_uri("http://nrs.harvard.edu/urn-3:FHCL:11403157")

                expect(uri).to eq("https://ids.lib.harvard.edu/ids/view/47373027")

               end
            end
            context "given a url without a urn-3" do
              it "returns the same url" do
                  uri = subject.fetch_ids_uri("http://ids.lib.harvard.edu/ids/view/7591643")

                  expect(uri).to eq("http://ids.lib.harvard.edu/ids/view/7591643")

               end
            end
        end

        describe "transform_ids_uri_to_iiif_manifest" do
          context "given an ids uri with no parameters" do
            it "returns an iiif uri" do
              uri = subject.transform_ids_uri_to_iiif_manifest("http://ids.lib.harvard.edu/ids/view/7591643")

              expect(uri).to eq("http://ids.lib.harvard.edu/ids/iiif/7591643/info.json")
            end
          end

          context "given an ids uri with parameters" do
            it "removes the parameters and returns an iiif uri" do
              uri = subject.transform_ids_uri_to_iiif_manifest("http://ids.lib.harvard.edu/ids/view/13890111?width=150&height=150&usethumb=y")

              expect(uri).to eq("http://ids.lib.harvard.edu/ids/iiif/13890111/info.json")
            end
          end

          context "given an ids uri with parameters" do
            it "removes the parameters" do
              uri = subject.fetch_ids_uri("http://ids.lib.harvard.edu/ids/view/13890111?width=150&height=150&usethumb=y")

              expect(uri).to eq("http://ids.lib.harvard.edu/ids/view/13890111")
            end
          end
        end

      describe 'parse_mods_data' do
        context 'given a sample xml file' do
          it 'verifies that the title can be extracted' do
            require "rexml/document"
            fixture_mods_file = file_fixture("mods_sample.xml")
            file = File.new(fixture_mods_file)
            doc = REXML::Document.new(file)
            subject.metadata = doc
            solr_hash = subject.parse_mods_record()
            expect(solr_hash['full_title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination: lecture [delivered], Sept. 7, 1774")
          end
        end
      end

   describe 'parse_mods_data no title' do
    context 'given a sample xml file' do
      it 'verifies that the parsing throws an error' do
        require "rexml/document"
        fixture_mods_file = file_fixture("mods_sample_no_title.xml")
        file = File.new(fixture_mods_file)
        doc = REXML::Document.new(file)
        subject.metadata = doc
        expect {subject.parse_mods_record()}.to raise_error(Spotlight::Resources::Exceptions::InvalidModsRecord)
      end
    end
  end

  describe 'parse_mods_data no id' do
    context 'given a sample xml file' do
      it 'verifies that the parsing throws an error' do
        require "rexml/document"
        fixture_mods_file = file_fixture("mods_sample_no_id.xml")
        file = File.new(fixture_mods_file)
        doc = REXML::Document.new(file)
        subject.metadata = doc
        expect {subject.parse_mods_record()}.to raise_error(Spotlight::Resources::Exceptions::InvalidModsRecord)
      end
    end
  end

  describe 'transform_urls' do
    context 'when adding the :VIEW suffix'
      let(:result) {"https://nrs.harvard.edu/urn-3:FHCL:562283:VIEW"}
      it 'strips params off and adds view' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283?buttons=y"
        expect(subject.transform_urls(url_string, 'VIEW')).to eq(result)
      end

      it 'strips params off and does not add view if view is present' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283:VIEW?buttons=y"
        expect(subject.transform_urls(url_string, 'VIEW')).to eq(result)
      end

      it 'strips params off and changes manifest for view' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283:MANIFEST?buttons=y"
        expect(subject.transform_urls(url_string, 'VIEW')).to eq(result)
      end

      it 'adds view if no params or view type is present' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283"
        expect(subject.transform_urls(url_string, 'VIEW')).to eq(result)
      end
    end

    context 'when adding the :MANIFEST suffix'
      let(:result) {"https://nrs.harvard.edu/urn-3:FHCL:562283:MANIFEST"}
      it 'strips params off and adds MANIFEST' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283?buttons=y"
        expect(subject.transform_urls(url_string, 'MANIFEST')).to eq(result)
      end

      it 'strips params off and does not add MANIFEST if MANIFEST is present' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283:MANIFEST?buttons=y"
        expect(subject.transform_urls(url_string, 'MANIFEST')).to eq(result)
      end

      it 'strips params off and changes manifest for MANIFEST' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283:MANIFEST?buttons=y"
        expect(subject.transform_urls(url_string, 'MANIFEST')).to eq(result)
      end

      it 'adds MANIFEST if no params or MANIFEST type is present' do
        url_string = "https://nrs.harvard.edu/urn-3:FHCL:562283"
        expect(subject.transform_urls(url_string, 'MANIFEST')).to eq(result)
      end
    end
  end
end
