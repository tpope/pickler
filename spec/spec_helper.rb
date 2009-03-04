$LOAD_PATH.unshift(File.join(File.dirname(File.dirname(__FILE__)),'lib'))
require 'pickler'
begin; require 'rubygems'; rescue LoadError; end
require 'spec'

Spec::Runner.configure do |config|
  config.before(:all) do
    require 'fake_web'
    directory = File.join(File.dirname(__FILE__),'tracker')
    Dir.chdir(directory) do
      Dir["**/*.xml"].each do |file|
        response = Net::HTTPOK.new("1.1","200","OK")
        response.instance_variable_set(:@body, File.read(file))
        response.add_field "Content-type", "application/xml"
        url = "http://www.pivotaltracker.com/services/v2/#{file.sub(/\.xml$/,'')}"
        FakeWeb.register_uri(url, :response => response)
      end
    end
  end

  config.after(:all) do
    FakeWeb.clean_registry
  end
end
