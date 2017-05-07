module Spotlight
  module Resources
    module Exceptions
      class InvalidModsRecord < StandardError
      end
    
      class InvalidMappingFile < StandardError
      end
      
      class ModsPathDoesNotExist < StandardError
      end
    end
  end
end