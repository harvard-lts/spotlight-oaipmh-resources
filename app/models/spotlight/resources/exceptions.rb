module Spotlight
  module Resources
    module Exceptions
      class InvalidModsRecord < StandardError
      end
    
      class InvalidMappingFile < StandardError
      end
      
      class ModsPathDoesNotExist < StandardError
      end
      
      class HarvestingFailedException < StandardError
      end
    end
  end
end