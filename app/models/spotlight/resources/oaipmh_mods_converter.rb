include Spotlight::Resources::Exceptions
module Spotlight::Resources
  
#  class ConditionalModsValue
#    attr_accessor :mods_attribute, :mods_attribute_value, :spotlight_value
#  end
#  class ConditionalModsPath
#    attr_accessor :value, :spotlight_value, :mods_path
#  end
  class ModsPath
    attr_accessor :path, :subpaths, :delimiter
  end
  class ModsItem
    attr_accessor :mods_path, :mods_attribute, :mods_attribute_value, :conditional_mods_value, :conditional_mods_path
  end
  class ConverterItem
    attr_accessor :spotlight_field, :mods_items, :default_value, :delimiter
    RESERVED_WORDS = {'name'=> "name_el", 'description' => 'description_el', 'type' => 'type_at'}
    
    def initialize()
      delimiter = ", "
    end
    
    def extract_value(modsrecord)
      value = ""
              
      mods_items.each do |item|
        #Throw error if path value fails
        begin
          node = modsrecord.mods_ng_xml
          values = parse_paths(item, node)
          
          if (values.empty? && !default_value.blank?)
            value = default_value
          else
            value = values.join(delimiter)
          end
        rescue NoMethodError
          print  "The path " + item.mods_path.path + " does not exist\n"
        end
      
      end
      value 
    end
      
    
    def parse_paths(item, parentnode)
      path_array = item.mods_path.path.split("/")
      path_array[0] = path_array[0].split(/(?<!^)(?=[A-Z])/)
      path_array[0] = path_array[0].join("_").downcase
      path_array.each_with_index do |value, key|
        #The mods gem has special names for certain reserved words/paths
        if (RESERVED_WORDS.key?(value))
          path_array[key] = RESERVED_WORDS[value]
        end
      end
      
      sub_delimiter = ","
      subpaths = Array.new
      if (!item.mods_path.subpaths.blank?)
         
        if (!item.mods_path.delimiter.blank?)
          sub_delimiter = item.mods_path.delimiter
        end
        item.mods_path.subpaths.each do |subpath|
          subpath_array = subpath.split("/")
          subpath_array.each_with_index do |value, key|
            #The mods gem has special names for certain reserved words/paths
            if (RESERVED_WORDS.key?(value))
              subpath_array[key] = RESERVED_WORDS[value]
            end
            
          end

          subpaths << subpath_array
        end
      end
       
       values = Array.new
       
       node = parentnode
       #eg: subject
       path_array.each do |path|
         node = node.send(path)    
       end
       #node.each do |subnode|
         if (!subpaths.empty?)
           subpathvalues = Array.new
           #subnodes when paths are stored in subpaths in the mapping file
           node.each do |subnode|  
             subpaths.each do |subpath_array|
               tempval = subnode
               
               #eg. subject/name/namePart
                subpath_array.each do |subpath|
                  tempval = tempval.send(subpath)
                end
                
                if (!tempval.text.empty? && check_attributes(tempval, item) && check_conditional_path(tempval, item, parentnode))
                  subpathvalues << tempval.text
                end
              end
              #puts subpathvalues.to_s
           if (!subpathvalues.empty?)
             #puts "delimiter: " + sub_delimiter
             values << subpathvalues.join(sub_delimiter)
           end
           end
         else
           node.each do |subnode|
            if (!subnode.text.blank? && check_attributes(subnode, item) && check_conditional_path(subnode, item, parentnode))
              values << subnode.text
            end
           end
         end
       #end
      values
    end
    
    def check_attributes(node, item)
      if (!item.mods_attribute.blank?)
        attribute = node[item.mods_attribute]
        if (item.mods_attribute_value[0].eql?("!") && !attribute.eql?(item.mods_attribute_value.delete("!")))
          value_accepted = true
        elsif (attribute.eql?(item.mods_attribute_value))
          value_accepted = true
        end
      else
        value_accepted = true
      end
      value_accepted
    end
    
    def check_conditional_path(node, item, parentnode)
      value_accepted = false
      if (!item.conditional_mods_value.blank?)
          path_array = item.conditional_mods_path.split("/")
          path_array[0] = path_array[0].split(/(?<!^)(?=[A-Z])/)
          path_array[0] = path_array[0].join("_").downcase
          path_array.each_with_index do |value, key|
            #The mods gem has special names for certain reserved words/paths
            if (RESERVED_WORDS.key?(value))
              path_array[key] = RESERVED_WORDS[value]
            end
          end
          
          conditionalnode = parentnode
          path_array.each do |path|
            conditionalnode = conditionalnode.send(path)    
          end
          if (item.conditional_mods_value[0].eql?("!") && !conditionalnode.text.eql?(item.conditional_mods_value.delete("!")))
            value_accepted = true
          elsif (conditionalnode.text.eql?(item.conditional_mods_value))
            value_accepted = true
          end
      else
        value_accepted = true
      end
      value_accepted
    end
end
  
  class OaipmhModsConverter
    RESERVED_PATHS = {'name/namePart'=> "personal_name/namePart", "name/role/roleTerm" => "personal_name/role/roleTerm", "title/titleInfo" => 'full_titles'}

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
    #            - mods-attribute: xxx
    #              mods-attribute-value: xxx (mods-value/spotlight-value and mods-path/spotlight-value are repeatable)
    #              spotlight-value: xxx 
    #            - mods-path: xxx (you don't need both mods-value and mods-path but you can use both)
    #              value: xxx (optional, use !xxx for exclusion)
    #              spotlight-value: xxx (defaults to path-text item if not present)
    #Expects a Mods::Record parameter value
    def convert(modsrecord)
      if (@converter_items.empty?)
        parse_mapping_file(mapping_file)
      end
      
      solr_hash = {}
        
      @converter_items.each do |item|
        solr_hash[item.spotlight_field] = item.extract_value(modsrecord)
      end
      solr_hash
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

  
  #private
  
  def parse_mapping_file(file)

    mapping_config = YAML.load_file(file)
    mapping_config.each do |field|
      
      item = ConverterItem.new
      #validate the spotlight-field is not null
      if (!field.key?("spotlight-field") || field['spotlight-field'].blank?)
        raise InvalidMappingFile, "spotlight-field is required for each entry"
      end
      item.spotlight_field = field['spotlight-field']
      
      if (field.key?("delimiter"))
        item.delimiter = field["delimiter"]
      end
      if (field.key?("default-value"))
        item.default_value = field["default-value"]
      end
      
      item.mods_items = Array.new
      field['mods'].each do |mods_field|
        modsitem = ModsItem.new
        #validate the path is not null
        if (!mods_field.key?("path") || mods_field['path'].blank?)
          raise InvalidMappingFile, "path is required for each mods entry"
        end
        
        modsitem.mods_path = ModsPath.new
        #The mods gem has special names for certain reserved words/paths
        if (RESERVED_PATHS.key?(mods_field['path']))
          modsitem.mods_path.path = RESERVED_PATHS[mods_field['path']]
        else
          modsitem.mods_path.path = mods_field['path']
        end
        
        if (mods_field.key?('subpaths'))
          subpaths = Array.new
          mods_field['subpaths'].each do |subpath|
            subpaths << subpath['subpath']
          end
          modsitem.mods_path.subpaths = subpaths
        end
        
        if (mods_field.key?('delimiter'))
          modsitem.mods_path.delimiter = mods_field['delimiter']
        end
        
        if (mods_field.key?('attribute'))
          if (!mods_field.key?('attribute-value'))
            raise InvalidMappingFile, field['spotlight-field'] + " - " + mods_field['path'] + ": attribute-value is required if attribute is present" 
          end
          modsitem.mods_attribute = mods_field['attribute']
          modsitem.mods_attribute_value = mods_field['attribute-value']
        end
        
        if (mods_field.key?('mods-path'))
          if (!mods_field.key?('mods-value'))
            raise InvalidMappingFile, field['spotlight-field'] + " - " + mods_field['path'] + ": mods-value is required if mods-path is present" 
          end
          if (RESERVED_PATHS.key?(mods_field['mods-path']))
            modsitem.conditional_mods_path = RESERVED_PATHS[mods_field['mods-path']]
          else
            modsitem.conditional_mods_path = mods_field['mods-path']
          end
          modsitem.conditional_mods_value = mods_field['mods-value']
        end

#        if (mods_field.key?('conditional'))
#          conditionals = mods_field['conditional']
#          modsitem.conditional_mods_value = ConditionalModsValue.new
#          modsitem.conditional_mods_path = Array.new
#          conditionals.each do |conditional|
#            if (conditional.key?('mods-attribute'))
#              if (!conditional.key?('mods-attribute-value'))
#                raise InvalidMappingFile, field['spotlight-field'] + " - " + mods_field['path'] + ": mods-attribute-value is required if mods-attribute is present"
#              end
#              if (!conditional.key?('spotlight-value'))
#                raise InvalidMappingFile, field['spotlight-field'] + " - " + mods_field['path'] + ": spotlight-value is required if mods-attribute is present"
#              end
#              cond = ConditionalModsValue.new
#              cond.mods_attribute = conditional['mods-attribute']
#              cond.mods_attribute_value = conditional['mods-attribute-value']
#              cond.spotlight_value = conditional['spotlight-value']
#              modsitem.conditional_mods_values << cond
#            end
#            if (conditional.key('mods-path'))
#              if (!conditional.key?('spotlight-value'))
#                raise InvalidMappingFile, field['spotlight-field'] + " - " + mods_field['path'] + ": value is required if mods-path is present"
#              end
#              cond = ConditionalModsPath.new
#              cond.mods_path = conditional['mods-path']
#              if (conditional.key?('spotlight-value'))
#                cond.spotlight_value = conditional['spotlight-value']
#              end
#              cond.value = conditional['value']
#              modsitem.conditional_mods_paths << cond
#            end
#          end
#        end
                
        item.mods_items << modsitem
      end
      @converter_items << item
    end
    @converter_items
  end
  
  
  end
end