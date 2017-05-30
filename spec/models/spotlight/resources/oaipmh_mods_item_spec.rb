require 'spec_helper'

  RSpec.describe Spotlight::Resources::OaipmhModsItem, type: :model do
    let(:exhibit) { FactoryGirl.create(:exhibit) }
    let(:converter) { Spotlight::Resources::OaipmhModsConverter.new('CNA', 'test-exhibit-name')}
    subject { described_class.new(exhibit, converter) }
      
#      describe "fetch_ids_uri" do
#          context "given a url with a urn-3" do
#            it "returns the resolving ids url" do
#                uri = subject.fetch_ids_uri("http://nrs.harvard.edu/urn-3:FHCL:11403157")
#                
#                expect(uri).to eq("http://ids.lib.harvard.edu/ids/view/47373027")
#                      
#               end
#            end
#            context "given a url without a urn-3" do
#              it "returns the same url" do
#                  uri = subject.fetch_ids_uri("http://ids.lib.harvard.edu/ids/view/7591643")
#                  
#                  expect(uri).to eq("http://ids.lib.harvard.edu/ids/view/7591643")
#                        
#               end
#            end
#        end
#        
#        describe "transform_ids_uri_to_iiif_manifest" do
#          context "given an ids uri with no parameters" do
#            it "returns an iiif uri" do
#              uri = subject.transform_ids_uri_to_iiif_manifest("http://ids.lib.harvard.edu/ids/view/7591643")
#              
#              expect(uri).to eq("http://ids.lib.harvard.edu/ids/iiif/7591643/info.json")
#            end
#          end
#          
#          context "given an ids uri with parameters" do
#            it "removes the parameters and returns an iiif uri" do
#              uri = subject.transform_ids_uri_to_iiif_manifest("http://ids.lib.harvard.edu/ids/view/13890111?width=150&height=150&usethumb=y")
#                            
#              expect(uri).to eq("http://ids.lib.harvard.edu/ids/iiif/13890111/info.json")
#            end
#          end
#          
#          context "given an ids uri with parameters" do
#            it "removes the parameters" do
#              uri = subject.fetch_ids_uri("http://ids.lib.harvard.edu/ids/view/13890111?width=150&height=150&usethumb=y")
#                            
#              expect(uri).to eq("http://ids.lib.harvard.edu/ids/view/13890111")
#            end
#          end
#        end
#        
      describe 'parse_mods_data' do
        context 'given a sample xml file' do
          it 'verifies that the title can be extracted' do
            require 'xml/libxml'
            fixture_mods_file = file_fixture("mods_sample.xml")
            doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
            #subject.metadata = doc
            solr_hash = subject.parse_mods_record(doc)
            expect(solr_hash['full_title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination")
          end
        end
      end
#      
#    describe 'parse_mods_ns_data' do
#        context 'given a sample xml file' do
#          it 'verifies that the title can be extracted' do
#            require 'xml/libxml'
#            fixture_mods_file = file_fixture("mymods.xml")
#            doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
#            md = xpath_first(doc, ".//metadata")
#            subject.metadata = md
#            subject.parse_mods_record
#            expect(subject.titles[0]).to eq("Letter from Universalist Church in Pike Run, Washington County, Pennsylvania, May 2, 1792")
#          end
#        end
#      end
      
   describe 'parse_mods_data no title' do
    context 'given a sample xml file' do
      it 'verifies that the parsing throws an error' do
        require 'xml/libxml'
        fixture_mods_file = file_fixture("mods_sample_no_title.xml")
        doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
        #subject.metadata = doc
        expect {subject.parse_mods_record(doc)}.to raise_error(Spotlight::Resources::Exceptions::InvalidModsRecord)
      end
    end
  end
    
    describe 'parse_mods_data no id' do
    context 'given a sample xml file' do
      it 'verifies that the parsing throws an error' do
        require 'xml/libxml'
        fixture_mods_file = file_fixture("mods_sample_no_id.xml")
        doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
        #subject.metadata = doc
        expect {subject.parse_mods_record(doc)}.to raise_error(Spotlight::Resources::Exceptions::InvalidModsRecord)
      end
    end
   end
   

end
