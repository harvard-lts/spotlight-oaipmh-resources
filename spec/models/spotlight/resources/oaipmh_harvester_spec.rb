require 'spec_helper'
require 'yaml'
include OAI::XPath


  RSpec.describe Spotlight::Resources::OaipmhHarvester, type: :model do
    let(:exhibit) { FactoryGirl.create(:exhibit) }
    #subject { described_class.create(exhibit_id: exhibit.id, data: {base_url: 'http://faulkner.hul.harvard.edu:9024/vcoai/vc', set: 'cna2'}) }
    subject { described_class.create(exhibit_id: exhibit.id, data: {base_url: 'http://faulkner.hul.harvard.edu:9024/oai', set: 'CNA'}) }

    describe "retrieval" do
          context "given a url and collection" do
            it "finds a list of records" do
              response = subject.oaipmh_harvests
              x = 0
              response.each do |record|
                modsonly = xpath_first(record.metadata, './/mods:mods')
#print modsonly.to_s
                modsrecord = Mods::Record.new.from_str(modsonly.to_s)
                titles = modsrecord.short_titles
               print "\n\nTitles:\n"
               for title in titles 
                 print title + "\n"
               end
               modsrecord.mods_ng_xml.origin_info.dateCreated.map do |e| 
                 print e.text
                 if e.get_attribute("point") 
                   print ": " + e.get_attribute("point") + "\n"
                 else
                   print "\n"
                 end
               end
                relations = modsrecord.mods_ng_xml.location.url  #.map { |e| e.text }
#               print "\n\nRelations:\n"
#               for relation in relations
#                 print relation.get_attribute("access") + ":\t"
#                 print relation.text + "\n"
#               end
                x += 1
                if (x > 1)
                  break
                end
              end
              expect(response).to be_instance_of(OAI::ListRecordsResponse)
              expect(response.entries.size).to be > 0
              expect(response.entries[0]).to be_instance_of(OAI::Record)       
            end
          end
      end
      
      
      
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
#        end
#        
#        describe "check oaipmh_mods_item" do
#          context "given a response, parse the mods" do
#            it "supplies an array of titles" do
#              response = subject.oaipmh_harvests
#              x = 0
#              response.full.each do |record|
#                modsonly = xpath_first(record.metadata, './/mods:mods')
#                modsrecord = Mods::Record.new.from_str(modsonly.to_s)
#                item = OaipmhModsItem.new(exhibit)
#                item.parse_mods_record(modsrecord)
#                titles = item.titles
#                for title in titles 
#                  print title + "\n"
#                end
#                x += 1
#                if (x > 1)
#                  break
#                end
#              end
#            end
#          end
#                        
#        end
#        
#        describe 'item.to_solr' do
#          
#          context "given a response, parse the mods" do
#            it "attempts to call to_solr" do
#              response = subject.oaipmh_harvests
#              x = 0
#              response.full.each do |record|
#                modsonly = xpath_first(record.metadata, './/mods:mods')
#                modsrecord = Mods::Record.new.from_str(modsonly.to_s)
#                item = OaipmhModsItem.new(:exhibit)
#                item.parse_mods_record(modsrecord)
#                expect(item.to_solr['full_title_tesim']).to eq("Postal Minister Yisrael Yishayahu inaugurates new mail office in Rosh HaAyin")
#                
#                x += 1
#                if (x > 0)
#                  break
#                end
#              end
#            end
#          end
#        end
#        
#    describe '#to_solr' do
#        
#        it 'returns an Enumerator of all the solr documents' do
#          subject.oaipmh_harvests
#          expect(subject.to_solr).to be_a(Enumerator)
#          expect(subject.to_solr.count).to eq 5
#        end
#    
#      end
  end

