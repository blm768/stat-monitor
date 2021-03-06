#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'etc'
require 'rubygems'
require 'rake'
require 'set'
require 'tmpdir'
require 'bundler'

task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts =%w{--color --format progress}
  task.pattern = 'spec/*_spec.rb'
end

task :docs do
  #To do: figure out why rdoc needs this deleted to process all files.
  FileUtils.rm_r('doc')
  system("rdoc --exclude '^spec$' --exclude '^snapshot$' --exclude '^rpm$' --exclude '^rpmbuild$' --exclude '^config$'")
end

task :rpm do
  #Remove any old versions and rebuild.
  #To do: don't remove the current version.
  Dir.glob('pkg/*') { |file| FileUtils.rm_r(file)}

  Rake::Task['build'].invoke

  package = Dir.glob('pkg/statmonitor-*.gem')[0]

  FileUtils.cp(package, 'rpm/SOURCES')

  home_dir = Etc.getpwuid.dir

  #If necessary, make a temporary backup of ~/rpmbuild.
  #To do: restore file even on exception
  old_rpmdir = nil

  if File.exists? File.join(home_dir, "rpmbuild")
    old_rpmdir = Dir.mktmpdir
    FileUtils.move(File.join(home_dir, 'rpmbuild'), old_rpmdir)
  end

  FileUtils.cp_r('rpm', home_dir)
  FileUtils.move(File.join(home_dir, 'rpm'), File.join(home_dir, 'rpmbuild'))

  rake_dir = Dir.pwd

  Dir.chdir(File.join(home_dir, 'rpmbuild'))

  system 'rpmbuild -ba SPECS/statmonitor.spec'

  Dir.chdir(rake_dir)

  #Clean up, keeping our rpmbuild directory within the project tree.
  FileUtils.rm_r("rpmbuild")
  FileUtils.move(File.join(home_dir, "rpmbuild"), "rpmbuild")
  if(old_rpmdir)
    FileUtils.move(old_rpmdir, File.join(home_dir, "rpmbuild"))
  end

  Dir.glob('rpm/SOURCES/*') { |file| FileUtils.rm(file) }

end
