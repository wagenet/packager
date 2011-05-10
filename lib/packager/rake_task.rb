require 'rbconfig'
require 'rake'
require 'rake/tasklib'

module Packager
  class RakeTask < ::Rake::TaskLib

    def initialize(name=:pkg, group=:packager, &block)
      namespace group do
        case os = RbConfig::CONFIG['host_os']
        when /mswin|windows|cygwin|mingw/i
          require 'packager/rake/windows_task'
          Packager::Rake::WindowsTask.new(&block)
        when /darwin/i
          require 'packager/rake/mac_task'
          Packager::Rake::MacTask.new(&block)
        else
          task :pkg do
            puts "Don't know how to package for: #{os}"
          end
        end
      end

      task name => "#{group}:pkg"
    end

  end
end
