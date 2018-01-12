# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'bundler/gem_helper'
require 'rubygems/package_task'
require 'pathname'
require 'uri'
require 'ostruct'
require 'rake/clean'
require 'rake_compiler_dock'
require_relative 'lib/libusb/libusb_recipe'
require_relative 'lib/libusb/gem_helper'

task :gem => :build
task :compile do
  sh "ruby -C ext extconf.rb --disable-system-libusb"
  sh "make -C ext install RUBYARCHDIR=../lib"
end

task :test=>:compile do
  sh "ruby -w -W2 -I. -Ilib -e \"#{Dir["test/test_*.rb"].map{|f| "require '#{f}';"}.join}\" -- -v"
end

travis_tests = %w[test_libusb_capability.rb test_libusb_structs.rb test_libusb_version.rb test_libusb_context.rb]
task :travis=>:compile do
  sh "ruby -w -W2 -I. -Ilib -e \"#{travis_tests.map{|f| "require 'test/#{f}';"}.join}\" -- -v"
end
task :default => :test

task 'gem:native' do
  sh "bundle package"
  RakeCompilerDock.sh <<-EOT
    bundle --local &&
    rake cross gem
  EOT
end

CrossLibraries = [
  ['x86-mingw32', 'i686-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x64-mingw32', 'x86_64-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x86-linux', 'i686-linux-gnu', 'lib/libusb-1.0.so'],
  ['x86_64-linux', 'x86_64-linux-gnu', 'lib/libusb-1.0.so'],
].map do |ruby_platform, host_platform, libusb_dll|
  LIBUSB::CrossLibrary.new ruby_platform, host_platform, libusb_dll
end

LIBUSB::GemHelper.install_tasks
Bundler::GemHelper.instance.cross_platforms = CrossLibraries.map(&:ruby_platform)

# vim: syntax=ruby
