#!/usr/bin/env rake
#require "bundler/gem_tasks"

require 'rubygems'
require 'rake'
require 'rake/extensiontask'
require 'bundler'

Rake::ExtensionTask.new("hello_world") do |extension|
  extension.lib_dir = 'lib/stat-monitor'
end

task :chmod do
  File.chmod(0775, 'lib/stat-monitor/utmp.so')
end

task :build => [:clean, :compile, :chmod]

Bundler::GemHelper.install_tasks
