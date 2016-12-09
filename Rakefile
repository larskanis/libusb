# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'bundler/gem_tasks'
require 'rubygems/package_task'
require 'pathname'
require 'uri'
require 'ostruct'
require 'rake/clean'
require 'rake_compiler_dock'
require_relative 'ext/libusb_recipe'

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

task "release:tag" do
  hfile = "History.md"
  version = LIBUSB::VERSION
  reldate = Time.now.strftime("%Y-%m-%d")
  headline = '([^\w]*)(\d+\.\d+\.\d+)([^\w]+)([2Y][0Y][0-9Y][0-9Y]-[0-1M][0-9M]-[0-3D][0-9D])([^\w]*|$)'

  hin = File.read(hfile)
  hout = hin.sub(/#{headline}/) do
    raise "#{hfile} isn't up-to-date for version #{version}" unless $2==version
    $1 + $2 + $3 + reldate + $5
  end
  if hout != hin
    Bundler.ui.confirm "Updating #{hfile} for release."
    File.write(hfile, hout)
    sh "git", "commit", hfile, "-m", "Update release date in #{hfile}"
  end

  Bundler.ui.confirm "Tag release with annotation:"
  m = hout.match(/(?<annotation>#{headline}.*?)#{headline}/m) || raise("Unable to find release notes in #{hfile}")
  Bundler.ui.info(m[:annotation].gsub(/^/, "    "))
  IO.popen(["git", "tag", "--file=-", version], "w") do |fd|
    fd.write m[:annotation]
  end
end

task "release:guard_clean" => "release:tag"

task "release:rubygem_push" => "gem:native" do
  CrossLibraries.each do |ruby_platform, _|
    gh = Bundler::GemHelper.new
    gh.send(:rubygem_push, "pkg/#{gh.gemspec.name}-#{gh.gemspec.version}-#{ruby_platform}.gem")
  end
end

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
    self.libusb_dll = Pathname.new(recipe.path) + libusb_dllname

    file libusb_dll do
      recipe.cook
    end

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

      # MiniPortile isn't required for native gems
      spec.dependencies.reject!{|d| d.name=="mini_portile2" }

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
  ['x86-mingw32', 'i686-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x64-mingw32', 'x86_64-w64-mingw32', 'bin/libusb-1.0.dll'],
  ['x86-linux', 'i686-linux-gnu', 'lib/libusb-1.0.so'],
  ['x86_64-linux', 'x86_64-linux-gnu', 'lib/libusb-1.0.so'],
].each do |ruby_platform, host_platform, libusb_dll|
  CrossLibrary.new ruby_platform, host_platform, libusb_dll
end

# vim: syntax=ruby
