module Spotlight
  class Harvester < ActiveRecord::Base
    belongs_to :exhibit

    validates :base_url, presence: true
    validates :set, presence: true

    def self.mapping_files(dir_name)
      if (Dir.exist?("public/uploads/#{dir_name}"))
        files = Dir.entries("public/uploads/#{dir_name}")
        files.delete('.')
        files.delete('..')
      else
        files = Array.new
      end

      files.insert(0, 'New Mapping File')
      files.insert(0, 'Default Mapping File')
      files
    end

    def get_mapping_file
      return if mapping_file.eql?('Default Mapping File') || mapping_file.eql?('New Mapping File')

      mapping_file
    end
  end
end
