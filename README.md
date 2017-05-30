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

## Usage

This is a Rails engine gem to be used along with blacklight-spotlight, another Rails engine gem used to build exhibits sites while leveraging the blacklight Rails engine gem.

This gem adds a new "Repository Item" form to your Spotlight application. This form allows curators to input a URL pointing to an OIA harvest and a set, and the contents of the feed will be harvested as new items in the Spotlight exhibit.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/harvard-library/spotlight-oaipmh-resources.



