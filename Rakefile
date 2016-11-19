# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'bundler/gem_tasks'
require 'rubygems/package_task'
require 'pathname'
require 'uri'
require 'ostruct'
require 'rake/clean'
require 'rake_compiler_dock'

task :gem => :build
task :compile do
  sh "ruby ext/extconf.rb --disable-system-libusb"
end

task :test=>:compile do
  sh "ruby -w -W2 -I. -Ilib -e \"#{Dir["test/test_*.rb"].map{|f| "require '#{f}';"}.join}\" -- -v"
end

travis_tests = %w[test_libusb_capability.rb test_libusb_structs.rb test_libusb_version.rb]
task :travis=>:compile do
  sh "ruby -w -W2 -I. -Ilib -e \"#{travis_tests.map{|f| "require 'test/#{f}';"}.join}\" -- -v"
end
task :default => :test

task 'gem:native' do
  sh "bundle package"
  RakeCompilerDock.sh <<-EOT
    sudo apt-get update &&
    sudo apt-get -y install libudev-dev libudev-dev:i386 &
    bundle --local &&
    rake cross gem
  EOT
end

class CrossLibrary < OpenStruct
  include Rake::DSL

  def initialize(ruby_platform, host_platform, libusb_dllname)
    super()

    self.ruby_platform = ruby_platform
    self.recipe = LibusbRecipe.new
    recipe.host = host_platform
    recipe.configure_options << "--host=#{recipe.host}"
    recipe.cook
    self.libusb_dll = Pathname.new(recipe.path) + libusb_dllname

    task "libusb_dll:#{ruby_platform}" => libusb_dll

    desc 'Cross compile libusb for win32'
    task :cross => [ "libusb_dll:#{ruby_platform}" ] do |t|
      spec = Gem::Specification::load("libusb.gemspec").dup
      spec.platform = Gem::Platform.new(ruby_platform)
      spec.extensions = []

      # Remove files unnecessary for native gems
      spec.files -= `git ls-files ext`.split("\n")
      spec.files.reject!{|f| f.start_with?('ports') }
      spec_text_files = spec.files.dup

      # Add native libusb-dll
      spec.files << "lib/#{libusb_dll.basename}"

      # Generate a package for this gem
      pkg = Gem::PackageTask.new(spec) do |pkg|
        pkg.need_zip = false
        pkg.need_tar = false
        # Do not copy any files per PackageTask, because
        # we need the files from the platform specific directory
        pkg.package_files.clear
      end

      # copy files of the gem to pkg directory
      file pkg.package_dir_path => spec_text_files do
        spec_text_files.each do |fn|
          f = File.join(pkg.package_dir_path, fn)
          fdir = File.dirname(f)
          mkdir_p(fdir) if !File.exist?(fdir)
          rm_f f
          safe_ln(fn, f)
        end

        # copy libusb.dll to pkg directory
        f = "#{pkg.package_dir_path}/lib/#{libusb_dll.basename}"
        mkdir_p File.dirname(f)
        rm_f f
        safe_ln libusb_dll.realpath, f
      end

      file "lib/#{libusb_dll.basename}" => [libusb_dll]
    end
  end
end

CrossLibraries = [
  ['i386-mingw32', 'i686-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x64-mingw32', 'x86_64-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x86-linux', 'i686-linux-gnu', 'lib/libusb-1.0.so'],
  ['x86_64-linux', 'x86_64-linux-gnu', 'lib/libusb-1.0.so'],
].map do |ruby_platform, host_platform, libusb_dll|
  CrossLibrary.new ruby_platform, host_platform, libusb_dll
end

# vim: syntax=ruby
