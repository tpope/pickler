begin; require 'rubygems'; rescue LoadError; end
require 'rake'
require 'rake/gempackagetask'

spec = eval(File.read(File.join(File.dirname(__FILE__),'pickler.gemspec')))
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = "--color"
    t.pattern = "spec/**/*_spec.rb"
  end
  task :default => :spec
rescue LoadError
end
