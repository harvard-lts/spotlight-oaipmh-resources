module Spotlight
  ##
  # Notify the curator that we're finished processing a
  # batch upload
  class HarvestingCompleteMailer < ActionMailer::Base
    def harvest_set_completed(job)
      @set = job.set
      @exhibit = job.exhibit
      @total_errors = job.harvester.total_errors
      @user = job.user
      subject = "Harvest indexing complete for #{@set}"
      subject += " with harvesting #{@total_errors} #{'error'.pluralize(@total_errors)}" if @total_errors.positive?
      mail(to: @user.email, from: 'oaiharvester@noreply.com', subject: subject)
    end
  end
end
