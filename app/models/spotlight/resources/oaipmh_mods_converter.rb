module Spotlight::Resources
  
  class ModsItem
    attr_accessor :mods_path, :mods_attribute, :mods_attribute_value
  end
  class ConverterItem
    attr_accessor :spotlight_field, :mods_items, :default_value, :delimiter
    
    def initialize()
      delimiter = ", "
    end
    
    def extract_value(modsrecord)
      value = ""
      mods_items.each do |item|
        path_array = item.mods_path.split("/")
        path_array[0] = path_array[0].split("(?<!^)(?=[A-Z])");
        path_array[0] = path_array[0].join("_")
        path = path_array.join(".")
        value = modsrecord.mods_ng_xml.path.text
      end
    end
  end
  
  class OaipmhModsConverter
    
    #Initialize with the name of the set being converted
    def initialize(set)
      @set = set
      @mapping_file = nil   
      @converter_items = Array.new  
    end
    
    #path: xxx (repeatable - all path fields will be concatenated)
    #          attribute: xxx (optional)
    #          attribute-value: xxx (optional, use '!xxx' for exclusion - NOTE you have to put the value in quotes when using '!')
    #          conditional: (optional)
    #            - mods-value: xxx (mods-value/spotlight-value and mods-path/spotlight-value are repeatable)
    #              spotlight-value: xxx (defaults to path-text item if not present)
    #            - mods-path: xxx (you don't need both mods-value and mods-path but you can use both)
    #              value: xxx (optional, use !xxx for exclusion)
    #              spotlig
    #Expects a Mods::Record parameter value
    def convert(modsrecord)
      if (@converter_items.empty?)
        parse_mapping_file
      end
      
      solr_hash = {}
        @converter_items
      #@converter_items.each do |item|
     #   solr_hash[item.spotlight_field] = item.extract_value(modsrecord)
     # end
    end
    

    #Retrieves the mapping file for the set, if one exists, otherwise uses the generic mapping file
    def mapping_file
      if (@mapping_file == nil)
        @mapping_file = Rails.root.join('config', @set.downcase + "_mapping.yml")
        if (!File.exists?(@mapping_file))
          @mapping_file = Rails.root.join('config', 'mapping.yml')
        end
      end
      @mapping_file        
    end

  
  private
  
  def parse_mapping_file()

    mapping_config = YAML.load_file(mapping_file)
    mapping_config.each do |field|
      item = ConverterItem.new
      #TODO validate the field is not null
      item.spotlight_field = field['spotlight-field']
      mods_field = field['mods']
      item.mods_items = Array.new
      field['mods'].each do |mods_field|
        modsitem = ModsItem.new
        #TODO - if validate the path is not null
        modsitem.mods_path = mods_field['path']
        if (mods_field['attribute'])
          modsitem.mods_attribute = mods_field['attribute']
        end
        if (mods_field['attribute-value'])
          modsitem.mods_attribute_value = mods_field['attribute-value']
        end
        item.mods_items << modsitem
      end
      @converter_items << item
    end
  end
  
  
  end
end