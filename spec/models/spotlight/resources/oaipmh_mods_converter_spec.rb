require 'spec_helper'
require 'yaml'
require 'oai'
require 'nokogiri'

include OAI::XPath
            

  RSpec.describe Spotlight::Resources::OaipmhModsConverter, type: :model do
    subject { described_class.new('CNA') }
    let(:abc_set) {described_class.new('ABC')}
      
      describe 'cna_mapping_config_file_exists' do
        context 'given a set name' do
          it 'verifies that the mapping file exists' do
            mapping_file = subject.mapping_file
            #expect(File.basename(mapping_file)).to eq('mapping.yml')
            print mapping_file + "\n"
            expect(File.basename(mapping_file)).to match(/cna_mapping.yml/i)
          end
        end
      end
      
      describe 'mapping_config_file_exists' do
        context 'given a set name with no mapping config' do
          it 'verifies that the default mapping file exists' do
            mapping_file = abc_set.mapping_file
            expect(File.basename(mapping_file)).to match(/mapping.yml/i)
          end
        end
      end
      
      describe 'mapping sample' do
        context 'given a set name' do
          it 'verifies that the expected fields exist' do
            fixture_mapping_file = file_fixture("mapping_sample.yml")
            mapping_config = YAML.load_file(fixture_mapping_file)
            
            require 'xml/libxml'
            fixture_mods_file = file_fixture("mods_sample.xml")
            
            doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
            modsonly = xpath_first(doc, "//*[local-name()='mods']")
            modsrecord = Mods::Record.new.from_str(modsonly.to_s)

            solr_hash = subject.convert(modsrecord)
#            expect(solr_hash['unique-id_tesim']).to eq("007139874")
#            expect(solr_hash['record-type_ssim']).to eq("collection")
#            expect(solr_hash['full_title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination: lecture [delivered], Sept. 7, 1774")
#            expect(solr_hash['citation-title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination: lecture [delivered], Sept. 7, 1774")
#            expect(solr_hash['creator_tesim']).to eq("Webster, Samuel , 1718-1796")
#            expect(solr_hash['start-date_tesim']).to eq("")
#            expect(solr_hash['end-date_tesim']).to eq("")
#            expect(solr_hash['date_tesim']).to eq("")
#            expect(solr_hash['contributer_tesim']).to eq("")
#            expect(solr_hash['spotlight_upload_description_tesim']).to eq("The hand-sewn notebook contains a manuscript draft of the Dudleian
#            lecture delivered by Samuel Webster on September 7, 1774 at Harvard College. The sermon
#            begins with the Biblical text Matt. 20:25-28. The copy includes a small number of edits
#            and struck-out words. The item is missing the back cover and appears to be missing its
#            final pages.|Received March 8, 1843 from President Quincy.")
#            expect(solr_hash['finding-aid_tesim']).to eq("")
#            expect(solr_hash['format_tesim']).to eq(".03 cubic feet (1 volume)|p. 20 x 16 cm.")
#            expect(solr_hash['language_ssim']).to eq("")
#            expect(solr_hash['repository_ssim']).to eq("Harvard University Archives")
#            expect(solr_hash['subjects_ssim']).to eq("Presbyterianism|Harvard College (1636-1780)--Sermons|Ordination--Early works to 1800")
#            expect(solr_hash['type_ssim']).to eq("Sermons-1774.|Lectures-Massachusetts-Cambridge-1774.")
#            expect(solr_hash['origin_ssim']).to eq("mau")
#            expect(solr_hash['biography_tesim']).to eq("mau")
#            expect(solr_hash['statement-of-responsibility_tesim']).to eq("mau")
#            expect(solr_hash['physical-form_tesim']).to eq("mau")
#            expect(solr_hash['language-info_tesim']).to eq("mau")
#            expect(solr_hash['publications_tesim']).to eq("mau")
                                                                                                              
            solr_hash.each {|key, value| puts "#{key} : #{value}" }
          end
        end
      end
      
#      describe 'verify mods values exist' do
#        context 'given a value' do
#          it 'verifies that the expected fields exist' do
#            require 'xml/libxml'
#            fixture_mods_file = file_fixture("mods_sample.xml")
#            
#            doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
#            modsonly = xpath_first(doc, "//*[local-name()='mods']")
#            modsrecord = Mods::Record.new.from_str(modsonly.to_s)
#
#            #print modsrecord.mods_ng_xml.location.physicalLocation.text
#            modsrecord.mods_ng_xml.location.each do |a|
#              print a.inspect
#              print "\n\n"
#            end
#          end
#        end
#      end
      
      describe 'parse mapping file' do
        context 'given a mapping file' do
          it 'verifies that no exception is thrown and that the converter_items has been populated' do
            fixture_mapping_file = file_fixture("mapping_sample.yml")
            expect {subject.parse_mapping_file(fixture_mapping_file) }.not_to raise_error 
            items = subject.parse_mapping_file(fixture_mapping_file)
            expect(items).not_to be_empty
          end
        end
      end
      
      describe 'mapping missing path value' do
        context 'given a mapping file missing a path value' do
          it 'verifies that an exception is thrown' do
            fixture_mapping_file = file_fixture("mapping_missing_path_value.yml")
            expect {subject.parse_mapping_file(fixture_mapping_file) }.to raise_error(Spotlight::Resources::Exceptions::InvalidMappingFile)  
          end
        end
      end
 
    describe 'mapping missing path' do
      context 'given a mapping file missing a mods path' do
        it 'verifies that an exception is thrown' do
          fixture_mapping_file = file_fixture("mapping_missing_path.yml")
          expect {subject.parse_mapping_file(fixture_mapping_file) }.to raise_error(Spotlight::Resources::Exceptions::InvalidMappingFile)  
        end
      end
    end

    describe 'mapping missing spotlight field value' do
      context 'given a mapping file missing a spotlight field value' do
        it 'verifies that an exception is thrown' do
          fixture_mapping_file = file_fixture("mapping_missing_spotlight_field_value.yml")
          expect {subject.parse_mapping_file(fixture_mapping_file) }.to raise_error(Spotlight::Resources::Exceptions::InvalidMappingFile)  
        end
      end
    end  
 
    describe 'mapping missing spotlight field' do
      context 'given a mapping file missing a spotlight field' do
        it 'verifies that an exception is thrown' do
          fixture_mapping_file = file_fixture("mapping_missing_spotlight_field.yml")
          expect {subject.parse_mapping_file(fixture_mapping_file) }.to raise_error(Spotlight::Resources::Exceptions::InvalidMappingFile)  
        end
      end
    end   
      
  end

