require 'rake'
require 'rake/gempackagetask'

spec = eval(File.read(File.join(File.dirname(__FILE__),'pickler.gemspec')))
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

task :default
