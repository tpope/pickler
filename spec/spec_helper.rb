$LOAD_PATH.unshift(File.join(File.dirname(File.dirname(__FILE__)),'lib'))
require 'pickler'
begin; require 'rubygems'; rescue LoadError; end
require 'rspec'

RSpec.configure do |config|
  config.before(:all) do
    require 'fake_web'
    directory = File.join(File.dirname(__FILE__), 'tracker')
    Dir.chdir(directory) do
      Dir["**/*.json"].each do |file|
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.instance_variable_set(:@body, File.read(file))
        response.add_field "Content-type", "application/json"
        url = "https://www.pivotaltracker.com/services/v5/#{file.sub(/\.json$/, '')}"
        FakeWeb.register_uri(:get, url, :response => response)
      end
      Dir["**/*.xml"].each do |file|
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.instance_variable_set(:@body, File.read(file))
        response.add_field "Content-type", "application/xml"
        url = "https://www.pivotaltracker.com/services/v3/#{file.sub(/\.xml$/, '')}"
        FakeWeb.register_uri(:get, url, :response => response)
      end
    end
  end

  config.after(:all) do
    FakeWeb.clean_registry
  end
end
