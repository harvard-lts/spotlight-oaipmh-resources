module Spotlight
  ##
  # Notify the curator that we're finished processing a
  # batch upload
  class HarvestingCompleteMailer < ActionMailer::Base
    def harvest_set_completed(job)
      @set = job.set
      @exhibit = job.exhibit
      @missing_sidecar_ids = job.missing_sidecar_ids
      @successful_sidecar_ids = job.successful_sidecar_ids
      @total_errors = job.harvester.total_errors
      @user = job.user
      subject = "Harvest indexing complete for #{@set}"
      subject += " with #{@missing_sidecar_ids.size} missing #{'sidecar'.pluralize(@missing_sidecar_ids.size)}" if @missing_sidecar_ids.present?
      subject += " with harvesting #{@total_errors} #{'error'.pluralize(@total_errors)}" if @total_errors.positive?
      mail(to: @user.email, from: 'oaiharvester@noreply.com', subject: subject)
    end
  end
end
