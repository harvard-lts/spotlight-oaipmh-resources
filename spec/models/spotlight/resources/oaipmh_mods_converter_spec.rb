require 'spec_helper'
require 'yaml'


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
            modsonly = xpath_first(fixture_mods_file, "//*[local-name()='mods']")
            #print modsonly.to_s
            modsrecord = Mods::Record.new.from_str(modsonly.to_s)
            
            #puts mapping_config.inspect
            ####TODO#####
#            mapping_config['spotlight-field'].each{ |field|
#              print field + "\n"
#            }
            items = subject.convert(nil)
            items.each do |i|
              print i.spotlight_field
              print "\n"
              print i.extract_value(modsrecord)
              print "\n"
            end
#            mapping_config.each do |field|
#              print field['spotlight-field'] + ":"
#              field['mods'].each do |mods_field|  
#                print "===>" + mods_field['path']
#                if (mods_field['attribute'])
#                  print "\tattribute" + mods_field['attribute']
#                end
#                if (mods_field['attribute-value'])
#                  print "===>" + mods_field['attribute-value']
#                end
#              end
#              print "\n"
#            end
          end
        end
      end
      
  end

