require 'rake'
require 'rake/gempackagetask'

spec = eval(File.read(File.join(File.dirname(__FILE__),'pickler.gemspec')))
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

begin
  require 'spec/rake/spectask'
  Spec::Rake::SpecTask.new(:spec) do |t|
    t.spec_files = FileList["spec/**/*_spec.rb"]
  end
  task :default => :spec
rescue LoadError
end
