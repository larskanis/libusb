# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'bundler/gem_helper'
require 'rubygems/package_task'
require 'pathname'
require 'uri'
require 'ostruct'
require 'rake/clean'
require_relative 'lib/libusb/libusb_recipe'
require_relative 'lib/libusb/gem_helper'

CLOBBER.include 'pkg'
CLEAN.include 'ports'
CLEAN.include 'tmp'
CLEAN.include 'ext/tmp'
CLEAN.include 'lib/*.a'
CLEAN.include 'lib/*.so*'
CLEAN.include 'lib/*.dll*'

task :build do
  require_relative 'lib/libusb/libusb_recipe'
  recipe = LIBUSB::LibusbRecipe.new
  recipe.download
end

task :gem => :build
task :compile do
  sh "ruby -C ext extconf.rb --disable-system-libusb"
  sh "make -C ext install RUBYARCHDIR=../lib"
end

task :gemfile_libusb_gem do
  gf = File.read("Gemfile")
  gf.gsub!(/^(gemspec)$/, "# \\1")
  gf << "\ngem 'libusb'\n"
  File.write("Gemfile_libusb_gem", gf)
  puts "Gemfile_libusb_gem written"
end

task :test do
  sh "ruby -w -W2 -I. -e \"#{Dir["test/test_*.rb"].map{|f| "require '#{f}';"}.join}\" -- -v"
end

ci_tests = %w[test_libusb.rb test_libusb_structs.rb]
task :ci do
  sh "ruby -w -W2 -I. -e \"#{ci_tests.map{|f| "require 'test/#{f}';"}.join}\" -- -v"
end
task :default => :test

CrossLibraries = [
  ['x86-mingw32', 'i686-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x64-mingw32', 'x86_64-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x64-mingw-ucrt', 'x86_64-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x86-linux-gnu', 'i686-linux-gnu', 'lib/libusb-1.0.so'],
  ['x86_64-linux-gnu', 'x86_64-linux-gnu', 'lib/libusb-1.0.so'],
  ['x86-linux-musl', 'i686-linux-gnu', 'lib/libusb-1.0.so'],
  ['x86_64-linux-musl', 'x86_64-linux-gnu', 'lib/libusb-1.0.so'],
].map do |ruby_platform, host_platform, libusb_dll|
  LIBUSB::CrossLibrary.new ruby_platform, host_platform, libusb_dll
end

LIBUSB::GemHelper.install_tasks
Bundler::GemHelper.instance.cross_platforms = CrossLibraries.map(&:ruby_platform)

CrossLibraries.map(&:ruby_platform).each do |platform|
  desc "Build windows and linux fat binary gems"
  multitask 'gem:native' => "gem:native:#{platform}"

  task "gem:native:#{platform}" do
    require 'rake_compiler_dock'
    sh "bundle package"
    RakeCompilerDock.sh <<-EOT, platform: platform
      bundle --local &&
      #{ "sudo yum install -y libudev-devel &&" if platform=~/linux-gnu/ }
      #{ "sudo apt-get update && sudo apt-get install -y libudev-dev &&" if platform=~/linux-musl/ }
      bundle exec rake --trace cross:#{platform} gem "MAKE=make V=1 -j`nproc`" || cat tmp/*/ports/libusb/*/*.log
    EOT
  end
end

# vim: syntax=ruby
