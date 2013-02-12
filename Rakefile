# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'bundler/gem_tasks'
require 'pathname'
require 'uri'
require 'rake/extensiontask'
require 'rake/extensioncompiler'

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

# Cross-compilation constants
COMPILE_HOME               = Pathname( "./tmp" ).expand_path
STATIC_SOURCESDIR          = COMPILE_HOME + 'sources'
STATIC_BUILDDIR            = COMPILE_HOME + 'builds'
RUBY_BUILD                 = RbConfig::CONFIG["host"]
CROSS_PREFIX = begin
  Rake::ExtensionCompiler.mingw_host
rescue => err
  $stderr.puts "Cross-compilation disabled -- %s" % [ err.message ]
  'unknown'
end

# Fetch tarball from sourceforge
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '1.0.9'
# LIBUSB_SOURCE_URI         = URI( "http://downloads.sourceforge.net/project/libusb/libusb-1.0/libusb-#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + File.basename( LIBUSB_SOURCE_URI.path )

# Fetch tarball from git repo
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '295c9d1'
# LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-#{LIBUSB_VERSION}.tar.bz2"

# Fetch tarball from libusbx
LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '1.0.14'
LIBUSB_SOURCE_URI         = URI( "http://downloads.sourceforge.net/project/libusbx/releases/#{LIBUSB_VERSION[/^\d+\.\d+\.\d+/]}/source/libusbx-#{LIBUSB_VERSION}.tar.bz2" )
LIBUSB_TARBALL            = STATIC_SOURCESDIR + File.basename( LIBUSB_SOURCE_URI.path )

# Fetch tarball from Pete Batard's git repo
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '4cc72d0'
# LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb-pbatard.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-pbatard-#{LIBUSB_VERSION}.tar.bz2"

# Static libusb build vars
STATIC_LIBUSB_BUILDDIR    = STATIC_BUILDDIR + LIBUSB_TARBALL.basename(".tar.bz2")
LIBUSB_CONFIGURE          = STATIC_LIBUSB_BUILDDIR + 'configure'
LIBUSB_MAKEFILE           = STATIC_LIBUSB_BUILDDIR + 'Makefile'
LIBUSB_DLL                = STATIC_LIBUSB_BUILDDIR + 'libusb/.libs/libusb-1.0.dll'

EXT_BUILDDIR              = Pathname( "./ext" ).expand_path
EXT_LIBUSB_BUILDDIR       = EXT_BUILDDIR + LIBUSB_TARBALL.basename(".tar.bz2")

#####################################################################
### C R O S S - C O M P I L A T I O N - T A S K S
#####################################################################

directory STATIC_SOURCESDIR.to_s

#
# Static libusb build tasks
#
directory STATIC_LIBUSB_BUILDDIR.to_s

# libusb source file should be stored there
file LIBUSB_TARBALL => STATIC_SOURCESDIR do |t|
  # download the source file using wget or curl
  chdir File.dirname(t.name) do
    url = LIBUSB_SOURCE_URI
    sh "wget '#{url}' -O #{LIBUSB_TARBALL}"
  end
end

# Extract the libusb builds
file STATIC_LIBUSB_BUILDDIR => LIBUSB_TARBALL do |t|
  sh 'tar', '-xjf', LIBUSB_TARBALL.to_s, '-C', STATIC_LIBUSB_BUILDDIR.parent.to_s
  LIBUSB_MAKEFILE.unlink if LIBUSB_MAKEFILE.exist?
end

file LIBUSB_CONFIGURE => STATIC_LIBUSB_BUILDDIR do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    sh "sh autogen.sh && make distclean"
  end
end

LIBUSB_ENV = [
  "CFLAGS='-fno-omit-frame-pointer'",
]

# generate the makefile in a clean build location
file LIBUSB_MAKEFILE => LIBUSB_CONFIGURE do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    options = [
      "--target=#{CROSS_PREFIX}",
      "--host=#{CROSS_PREFIX}",
      "--build=#{RUBY_BUILD}",
    ]

    configure_path = STATIC_LIBUSB_BUILDDIR + 'configure'
    sh "env #{[LIBUSB_ENV, configure_path.to_s, *options].join(" ")}"
  end
end

# make libusb-1.0.a
task LIBUSB_DLL => [ LIBUSB_MAKEFILE ] do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    sh 'make'
  end
end

# copy binary from temporary location to final lib
task "copy:libusb_dll" => ['lib', LIBUSB_DLL] do
  install LIBUSB_DLL, "lib/#{File.basename(LIBUSB_DLL)}"
end

desc "compile static libusb libraries"
task :libusb_dll => [ "copy:libusb_dll" ]

desc 'Cross compile libusb for win32'
task :cross => [ :mingw32, :libusb_dll ] do |t|
  spec = Gem::Specification::load("libusb.gemspec")
  spec.instance_variable_set(:"@cache_file", nil) if spec.respond_to?(:cache_file)
  spec.platform = Gem::Platform.new('i386-mingw32')
  spec.files << "lib/#{File.basename(LIBUSB_DLL)}"
  spec.files -= `git ls-files ext`.split("\n")
  spec.extensions = []

  # Generate a package for this gem
  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end
end

task :mingw32 do
  # Use Rake::ExtensionCompiler helpers to find the proper host
  unless Rake::ExtensionCompiler.mingw_host then
    warn "You need to install mingw32 cross compile functionality to be able to continue."
    warn "Please refer to your distribution/package manager documentation about installation."
    fail
  end
end

desc "Download and update bundled libusb(x)"
task :update_libusb => LIBUSB_TARBALL do
  sh 'rm', '-r', (EXT_BUILDDIR + "libusbx-*").to_s do end
  sh 'git', 'rm', '-rfq', (EXT_BUILDDIR + "libusbx-*").to_s do end
  sh 'tar', '-xjf', LIBUSB_TARBALL.to_s, '-C', EXT_LIBUSB_BUILDDIR.parent.to_s
  drops = %w[msvc].map{|f| (EXT_LIBUSB_BUILDDIR+f).to_s }
  sh 'rm', '-r', '-f', *drops
  sh 'git', 'add', EXT_LIBUSB_BUILDDIR.to_s
end

# vim: syntax=ruby
