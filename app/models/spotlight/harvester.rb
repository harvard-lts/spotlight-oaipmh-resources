module Spotlight
  class Harvester < ActiveRecord::Base
    belongs_to :exhibit

    validates :base_url, presence: true
    validates :set, presence: true
  end
end
