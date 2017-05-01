begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end


require 'engine_cart/rake_task'
desc 'Run tests in generated test Rails app with generated Solr instance running'
task ci: ['engine_cart:generate'] do
  require 'solr_wrapper'
  require 'exhibits_solr_conf'
  ENV['environment'] = 'test'
  SolrWrapper.wrap(port: '8983') do |solr|
    solr.with_collection(name: 'blacklight-core', dir: ExhibitsSolrConf.path) do
      # run the tests
      Rake::Task['spec'].invoke
    end
  end
end
#ZIP_URL = "https://github.com/projectblacklight/blacklight-jetty/archive/v4.10.4.zip"
#require 'jettywrapper'
#
#require 'engine_cart/rake_task'
#EngineCart.fingerprint_proc = EngineCart.rails_fingerprint_proc
#
#require 'exhibits_solr_conf'
#
#desc 'Run tests in generated test Rails app with generated Solr instance running'
#task ci: ['engine_cart:generate', 'jetty:clean', 'exhibits:configure_solr'] do
#  ENV['environment'] = 'test'
#  jetty_params = Jettywrapper.load_config
#  jetty_params[:startup_wait] = 60
#
#  Jettywrapper.wrap(jetty_params) do
#    # run the tests
#    Rake::Task['spec'].invoke
#  end
#end

#RDoc::Task.new(:rdoc) do |rdoc|
#  rdoc.rdoc_dir = 'rdoc'
#  rdoc.title    = 'SpotlightOaipmh'
#  rdoc.options << '--line-numbers'
#  rdoc.rdoc_files.include('README.rdoc')
#  rdoc.rdoc_files.include('lib/**/*.rb')
#end



load 'rails/tasks/statistics.rake'



Bundler::GemHelper.install_tasks

