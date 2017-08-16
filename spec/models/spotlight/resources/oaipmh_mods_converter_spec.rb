require 'spec_helper'
require 'yaml'
require 'oai'
require 'nokogiri'
require 'language'
require 'xml/libxml'

include OAI::XPath
            

  RSpec.describe Spotlight::Resources::OaipmhModsConverter, type: :model do
    subject { described_class.new('CNA', 'test-exhibit-name',File.dirname(__FILE__) + "/../../../fixtures/files/cna_mapping.yml") }
    let(:abc_set) {described_class.new('ABC', 'test-exhibit-name',File.dirname(__FILE__) + "/../../../fixtures/files/mapping_sample.yml")}
      
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
            expect(solr_hash['unique-id_tesim']).to eq("007139874")
            #expect(solr_hash['record-type_ssim']).to eq("collection")
            expect(solr_hash['full_title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination: lecture [delivered], Sept. 7, 1774")
            #expect(solr_hash['citation-title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination: lecture [delivered], Sept. 7, 1774")
            expect(solr_hash['exhibit_test-exhibit-name_creator_tesim']).to eq("Webster, Samuel , 1718-1796")
            expect(solr_hash['exhibit_test-exhibit-name_start-date_tesim']).to eq("1774mau")
            expect(solr_hash['exhibit_test-exhibit-name_end-date_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_date_tesim']).to eq("1774")
            expect(solr_hash['exhibit_test-exhibit-name_contributer_tesim']).to be_nil
#            expect(solr_hash['spotlight_upload_description_tesim']).to eq("The hand-sewn notebook contains a manuscript draft of the Dudleian
#            lecture delivered by Samuel Webster on September 7, 1774 at Harvard College. The sermon
#            begins with the Biblical text Matt. 20:25-28. The copy includes a small number of edits
#            and struck-out words. The item is missing the back cover and appears to be missing its
#            final pages.|Received March 8, 1843 from President Quincy.")
            expect(solr_hash['exhibit_test-exhibit-name_format_tesim']).to eq(".03 cubic feet (1 volume)|p. 20 x 16 cm.")
            expect(solr_hash['exhibit_test-exhibit-name_language_ssim']).to eq("eng")
            expect(solr_hash['exhibit_test-exhibit-name_repository_ssim']).to eq("Harvard University Archives")
            expect(solr_hash['exhibit_test-exhibit-name_subjects_ssim']).to eq("Presbyterianism|Harvard College (1636-1780)--Sermons|Ordination--Early works to 1800")
            expect(solr_hash['exhibit_test-exhibit-name_type_ssim']).to eq("Sermons-1774., Lectures-Massachusetts-Cambridge-1774.")
            expect(solr_hash['exhibit_test-exhibit-name_origin_ssim']).to eq("mau")
#            expect(solr_hash['exhibit_test-exhibit-name_biography_tesim']).to eq('Samuel Webster (1718-1796), minister of Second Church of the West Parish
#            of Salisbury, Mass., was born on August 16, 1718 in Bradford, Mass. He received an AB
#            from Harvard in 1737 and an AM in 1740. He was ordained as a minister of the Rocky Hill
#            meetinghouse of the West Parish of Salisbury on August 12, 1741. In 1777 he delivered
#            the Election Sermon to the Massachusetts General Court. He received a doctorate in
#            sacred theology from Harvard in 1792. Webster died on July 18, 1796.|Harvard\'s oldest endowed lecture, the annual Dudleian
#            lecture, is funded by a bequest from the 1750 will of the Chief Justice of Massachusetts
#            Paul Dudley (1675-1750/1). Dudley specified that the topics of the annual sermon were to
#            rotate among four themes: natural religion, revealed religion, the "Romish church," and
#            the validity of the ordination of ministers. The first lecture was given in 1755, and
#            the series continued uninterrupted until 1857, when the fund was suspended to allow for
#            accumulation. The lecture series began again in 1888. In 1911, the Trustees voted to
#            discontinue the third lecture topic, and the series continued rotating among the three
#            topics until 1956, when another lecture topic, "Catholicism and Protestantism," was
#            voted into the rotation.')
            expect(solr_hash['exhibit_test-exhibit-name_statement-of-responsibility_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_physical-form_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_language-info_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_publications_tesim']).to be_nil
          end
        end
      end
      
      describe 'cna mapping sample single item' do
        context 'given a set name' do
          it 'verifies that the expected fields exist' do
            fixture_mapping_file = file_fixture("mapping_sample.yml")
            mapping_config = YAML.load_file(fixture_mapping_file)
            
            
            fixture_mods_file = file_fixture("mods_sample_single_item.xml")
            
            doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
            modsonly = xpath_first(doc, "//*[local-name()='mods']")
            modsrecord = Mods::Record.new.from_str(modsonly.to_s)
            
            mynode = modsrecord.mods_ng_xml.send('name')
            
            solr_hash = subject.convert(modsrecord)
            expect(solr_hash['unique-id_tesim']).to eq("008704078")
            #expect(solr_hash['exhibit_test-exhibit-name_record-type_ssim']).to eq("item")
            expect(solr_hash['full_title_tesim']).to eq("Commission of Noah Cooke, Jr., as chaplain in the Continental Army, signed by John Hancock, 1776 January 1")
            expect(solr_hash['exhibit_test-exhibit-name_collection-title_ssim']).to be_nil
            #expect(solr_hash['citation-title_tesim']).to eq("Mr. Webster's Dudleian lecture on Presbyterian ordination: lecture [delivered], Sept. 7, 1774")
            expect(solr_hash['exhibit_test-exhibit-name_creator_tesim']).to eq("United States , Continental Congress.")
            expect(solr_hash['exhibit_test-exhibit-name_start-date_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_end-date_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_date_tesim']).to eq("1776")
            expect(solr_hash['exhibit_test-exhibit-name_contributer_tesim']).to eq("Hancock, John , 1737-1793 , Cooke, Noah , 1749-1829")
           #expect(solr_hash['spotlight_upload_description_tesim']).to eq('Commission of Noah Cooke, Jr., as chaplain in the Continental Army, signed by John Hancock, 1 January 1776.|Transcription of document: "In Congress. The delegates of the United Colonies of New-Hampshire, Massachusetts-Bay, Rhode-Island, Connecticut, New-York, New-Jersey, Pennsylvania, the Counties of Newcastle, Kent, and Suffolk on Delaware, Maryland, Virginia, North-Carolina, and South Carolina to the Reverend Noah Cooke Junr. We [...] do by these presents constitute and appoint you to be Chaplain of the fifth Regiment of Foot Commanded by Colonel John Stark, and to the eighth Regiment Commanded by Colonel Enoch Poor in the army of the United Colonies, raised for the defense of American Liberty, and for repelling every invasion thereof [...].|Title supplied by cataloger.|Transferred from the Fogg Art Museum (originally received from one of the Harvard houses) to the Harvard University Library on September 14, 1955. On the verso there is a Harvard University Library stamp in black ink; the month "SEP" is included in the stamp. The remainder of the date was added in graphite: "14, 1955".|Pasted to paperboard backing.')
            expect(solr_hash['exhibit_test-exhibit-name_format_tesim']).to eq(".14 linear feet (1 document)")
            expect(solr_hash['exhibit_test-exhibit-name_language_ssim']).to eq("eng")
            expect(solr_hash['exhibit_test-exhibit-name_repository_ssim']).to eq("HUA")
            #expect(solr_hash['exhibit_test-exhibit-name_subjects_ssim']).to eq("Cooke, Noah|United States.--Continental Army--Chaplains|Military chaplains--United States|United States--History--sources")
            expect(solr_hash['exhibit_test-exhibit-name_type_ssim']).to eq("Commissions (permissions).")
            expect(solr_hash['exhibit_test-exhibit-name_origin_ssim']).to eq("xxu")
            expect(solr_hash['exhibit_test-exhibit-name_biography_tesim']).to eq('Noah Cooke, Jr. (1749-1829) earned his Harvard AB 1769. His early career was as a clergyman, but he later became a lawyer. He was admitted to the bar in Cheshire County, New Hampshire in 1784. He practiced law in New Ipswich and Keene. Cooke held a variety of local offices in Keene. See biographical sketch in Sibley\'s Harvard Graduates, Vol. XVII.')
            expect(solr_hash['exhibit_test-exhibit-name_statement-of-responsibility_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_physical-form_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_language-info_tesim']).to be_nil
            expect(solr_hash['exhibit_test-exhibit-name_publications_tesim']).to be_nil
          end
        end
      end
      
      describe 'parse cna mods single item' do
       context 'get the hollis record and finding aid' do
         it 'verifies that the expected fields exist' do
           fixture_mods_file = file_fixture("mods_sample_single_item.xml")
           cna_config = YAML.load_file(file_fixture('cna_config.yml'))['development']
           
           doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
           modsonly = xpath_first(doc, "//*[local-name()='mods']")
           modsrecord = Mods::Record.new.from_str(modsonly.to_s)
                       
           fa = modsrecord.mods_ng_xml.xpath(cna_config['FINDING_AID_XPATH'])
             if (fa.blank?)
               fa = nil
         
             end
           hr = modsrecord.mods_ng_xml.xpath(cna_config['HOLLIS_RECORD_XPATH'])
           expect(fa).to be_nil
           expect(hr.text).to eq("http://id.lib.harvard.edu/aleph/008704078/catalog")
         end
       end
     end
     
     describe 'parse cna mods sample item' do
       context 'get the hollis record and finding aid' do
         it 'verifies that the expected fields exist' do
           fixture_mods_file = file_fixture("mods_sample_item.xml")
           cna_config = YAML.load_file(file_fixture('cna_config.yml'))['development']
           
           doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
           modsonly = xpath_first(doc, "//*[local-name()='mods']")
           modsrecord = Mods::Record.new.from_str(modsonly.to_s)
           fa = modsrecord.mods_ng_xml.xpath(cna_config['FINDING_AID_XPATH'])
           hr = modsrecord.mods_ng_xml.xpath(cna_config['HOLLIS_RECORD_XPATH'])
           expect(fa.text).to eq("http://id.lib.harvard.edu/ead/hou01499/catalog")
           expect(hr.text).to eq("http://id.lib.harvard.edu/aleph/000601800/catalog")                      
         end
       end
     end 
     
     describe 'parse cna mods sample item with multiple repositories' do
       context 'repository' do
         it 'verifies that only one repository is used' do
           fixture_mods_file = file_fixture("mods_sample_item_many_repos.xml")
           
           doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
           modsonly = xpath_first(doc, "//*[local-name()='mods']")
           modsrecord = Mods::Record.new.from_str(modsonly.to_s)
           solr_hash = subject.convert(modsrecord)
           repoarray = solr_hash['exhibit_test-exhibit-name_repository_ssim'].split("|")
           repoarray = repoarray.uniq
           repo = repoarray.join("|")

           expect(repo).to eq("Harvard University Archives")
         end
       end
     end 
     
     
     describe 'parse cna mods sample item with irregular title' do
       context 'titles with irregular sort/non sort settings' do
         it 'verifies that the full title is being populated' do
           fixture_mods_file = file_fixture("mods_sample_odd_title.xml")
           
           doc = LibXML::XML::Document.file(fixture_mods_file.to_s)
           modsonly = xpath_first(doc, "//*[local-name()='mods']")
           modsrecord = Mods::Record.new.from_str(modsonly.to_s)
           solr_hash = subject.convert(modsrecord)
           title = solr_hash['full_title_tesim']
           expect(title).to eq("A system of ethicks: Of morall phylosophy in generall & in speciall")
         end
       end
     end  
     
     
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

