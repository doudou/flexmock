require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/*_test.rb']
end

task :test_rspec do
    if !system('rspec', 'test/rspec_integration')
        puts "RSpec tests failed"
        exit 1
    end
end

task :default => :test
