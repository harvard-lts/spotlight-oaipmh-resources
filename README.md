# Spotlight::Resources::Oaipmh

Spotlight Resource Harvester for OAI-PMH.  A Rails engine gem for use in the blacklight-spotlight Rails engine gem.

## Installation

Add this line to your blacklight-spotlight Rails application's Gemfile:

```ruby
gem 'spotlight-oaipmh-resources'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install spotlight-oaipmh-resources

Then run the engine's generator:

    $ rails generate spotlight:oaipmh:resources:install

Furthermore, this engine runs the harvester as a background job.  To set up the job, install solid_queue
in your Spotlight Gemfile:
```ruby
gem 'solid_queue'
gem 'mission_control-jobs'
```

Make a tmp/pids directory:

	$ mkdir tmp/pids

Add the solid_queue as the queue_adapter to config/application.rb:

```ruby
config.active_job.queue_adapter = :solid_queue
```

## Usage

This is a Rails engine gem to be used along with blacklight-spotlight, another Rails engine gem used to build exhibits sites while leveraging the blacklight Rails engine gem.

This gem adds a new "Repository Item" form to your Spotlight application. This form allows curators to input a URL pointing to an OIA harvest and a set, and the contents of the feed will be harvested as new items in the Spotlight exhibit.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/harvard-library/spotlight-oaipmh-resources.
