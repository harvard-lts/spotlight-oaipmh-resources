module Spotlight
  class Harvester < ActiveRecord::Base
    belongs_to :exhibit

    attr_accessor :total_errors

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

    def handle_item_harvest_error(error, parsed_item, job_tracker = nil)
      error_msg = parsed_item.id + ' did not index successfully:'
      Rails.logger.error(error_msg)
      Rails.logger.error(error.message)
      Rails.logger.error(error.backtrace)
      if job_tracker.present?
        job_tracker.append_log_entry(type: :error, exhibit: exhibit, message: error_msg)
        job_tracker.append_log_entry(type: :error, exhibit: exhibit, message: error.message)
      end
      self.total_errors += 1
    end

    def update_progress_total(job_progress)
      job_progress.total = complete_list_size
    end

    def get_mapping_file
      return if mapping_file.eql?('Default Mapping File') || mapping_file.eql?('New Mapping File')

      mapping_file
    end
  end
end
