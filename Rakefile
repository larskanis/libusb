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
  sh "ruby ext/extconf.rb"
end

task :test=>:compile do
  sh "ruby -w -W2 -I. -Ilib -e \"#{Dir["test/test_*.rb"].map{|f| "require '#{f}';"}.join}\" -- -v"
end

travis_tests = %w[test_libusb_capability.rb test_libusb_structs.rb test_libusb_version.rb]
task :travis=>:compile do
  sh "ruby -w -W2 -I. -Ilib -e \"#{travis_tests.map{|f| "require 'test/#{f}';"}.join}\" -- -v"
end
task :default => :test

task 'gem:windows' do
  RakeCompilerDock.sh "bundle && rake cross gem MAKE=\"make -j `nproc`\""
end

COMPILE_HOME               = Pathname( "./tmp" ).expand_path
STATIC_SOURCESDIR          = COMPILE_HOME + 'sources'

# Fetch tarball from sourceforge
LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '1.0.19'
LIBUSB_SOURCE_URI         = URI( "http://downloads.sourceforge.net/project/libusb/libusb-1.0/libusb-#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2" )
LIBUSB_TARBALL            = STATIC_SOURCESDIR + File.basename( LIBUSB_SOURCE_URI.path )

# Fetch tarball from git repo
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '295c9d1'
# LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-#{LIBUSB_VERSION}.tar.bz2"

# Fetch tarball from libusbx
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '1.0.17'
# LIBUSB_SOURCE_URI         = URI( "http://downloads.sourceforge.net/project/libusbx/releases/#{LIBUSB_VERSION[/^\d+\.\d+\.\d+/]}/source/libusbx-#{LIBUSB_VERSION}.tar.bz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + File.basename( LIBUSB_SOURCE_URI.path )

# Fetch tarball from Pete Batard's git repo
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '4cc72d0'
# LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb-pbatard.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-pbatard-#{LIBUSB_VERSION}.tar.bz2"

EXT_BUILDDIR              = Pathname( "./ext" ).expand_path
EXT_LIBUSB_BUILDDIR       = EXT_BUILDDIR + LIBUSB_TARBALL.basename(".tar.bz2")

directory STATIC_SOURCESDIR.to_s

# libusb source file should be stored there
file LIBUSB_TARBALL => STATIC_SOURCESDIR do |t|
  # download the source file using wget or curl
  chdir File.dirname(t.name) do
    url = LIBUSB_SOURCE_URI
    sh "wget '#{url}' -O #{LIBUSB_TARBALL}"
  end
end


class CrossLibrary < OpenStruct
  include Rake::DSL

  def initialize(ruby_platform, host_platform)
    super()

    self.ruby_platform              = ruby_platform
    self.host_platform              = host_platform

    self.static_builddir            = COMPILE_HOME + 'builds' + ruby_platform
    self.ruby_build                 = RbConfig::CONFIG["host"]

    # Static libusb build vars
    self.static_libusb_builddir    = static_builddir + LIBUSB_TARBALL.basename(".tar.bz2")
    self.libusb_configure          = static_libusb_builddir + 'configure'
    self.libusb_makefile           = static_libusb_builddir + 'Makefile'
    self.libusb_dll                = static_libusb_builddir + 'libusb/.libs/libusb-1.0.dll'

    #
    # Static libusb build tasks
    #
    CLEAN.include static_libusb_builddir.to_s

    directory static_libusb_builddir.to_s

    # Extract the libusb builds
    file static_libusb_builddir => LIBUSB_TARBALL do |t|
      sh 'tar', '-xjf', LIBUSB_TARBALL.to_s, '-C', static_libusb_builddir.parent.to_s
      libusb_makefile.unlink if libusb_makefile.exist?
    end

    file libusb_configure => static_libusb_builddir do |t|
      Dir.chdir( static_libusb_builddir ) do
        sh "sh autogen.sh && make distclean"
      end
    end

    libusb_env = [
      "CFLAGS='-fno-omit-frame-pointer'",
      "LDFLAGS='-static-libgcc'",
      "CC='#{host_platform}-gcc -static-libgcc'", # hack libtool, since it doesn't support -static-libgcc yet.
    ]

    # generate the makefile in a clean build location
    file libusb_makefile => libusb_configure do |t|
      Dir.chdir( static_libusb_builddir ) do
        options = [
          "--target=#{host_platform}",
          "--host=#{host_platform}",
          "--build=#{ruby_build}",
        ]

        configure_path = static_libusb_builddir + 'configure'
        sh "env #{[libusb_env, configure_path.to_s, *options].join(" ")}"
      end
    end

    # make libusb-1.0.dll
    task libusb_dll => [ libusb_makefile ] do |t|
      Dir.chdir( static_libusb_builddir ) do
        sh 'make'
      end
    end

    task "libusb_dll:#{ruby_platform}" => libusb_dll

    desc 'Cross compile libusb for win32'
    task :cross => [ "libusb_dll:#{ruby_platform}" ] do |t|
      spec = Gem::Specification::load("libusb.gemspec").dup
      spec.platform = Gem::Platform.new(ruby_platform)
      spec.extensions = []
      spec.files -= `git ls-files ext`.split("\n")
      spec_text_files = spec.files.dup
      spec.files << "lib/#{File.basename(libusb_dll)}"

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
        f = "#{pkg.package_dir_path}/lib/#{File.basename(libusb_dll)}"
        mkdir_p File.dirname(f)
        rm_f f
        safe_ln libusb_dll, f
      end

      file "lib/#{File.basename(libusb_dll)}" => [libusb_dll]
    end
  end
end

CrossLibraries = [
  ['i386-mingw32', 'i686-w64-mingw32'],
  ['x64-mingw32', 'x86_64-w64-mingw32'],
].map do |ruby_platform, host_platform|
  CrossLibrary.new ruby_platform, host_platform
end

desc "Download and update bundled libusb"
task :update_libusb => LIBUSB_TARBALL do
  sh 'rm', '-r', (EXT_BUILDDIR + "libusb-*").to_s do end
  sh 'git', 'rm', '-rfq', (EXT_BUILDDIR + "libusb-*").to_s do end
  sh 'tar', '-xjf', LIBUSB_TARBALL.to_s, '-C', EXT_LIBUSB_BUILDDIR.parent.to_s
  drops = %w[msvc].map{|f| (EXT_LIBUSB_BUILDDIR+f).to_s }
  sh 'rm', '-r', '-f', *drops
  sh 'git', 'add', EXT_LIBUSB_BUILDDIR.to_s
end

# vim: syntax=ruby
