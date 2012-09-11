#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'rubygems'
require 'rake'
#require 'rake/extensiontask'
require 'bundler'

task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts =%w{--color --format progress}
  task.pattern = 'spec/*_spec.rb'
end
