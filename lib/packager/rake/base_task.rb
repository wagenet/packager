require 'rake'
require 'rake/tasklib'
require 'erb'
require 'rbconfig'
require 'packager'

module Packager
  module Rake
    class BaseTask < ::Rake::TaskLib

      attr_accessor :version

      attr_accessor :package_name

      attr_accessor :short_package_name

      attr_accessor :domain

      attr_accessor :bin_files

      attr_accessor :resource_files

      def initialize
        @domain = 'gemcutter.org'
        @bin_files = []
        @resource_files = []
        @package_name, @short_package_name = nil

        yield self if block_given?

        if !@package_name || @package_name.empty?
          raise "package_name is required"
        end

        @short_package_name ||= package_name.downcase.gsub(/\W+/,'-')
      end

      def ruby_bin_path
        nil
      end

      private

        def setup_bundler
          require 'bundler/shared_helpers'

          unless Bundler::SharedHelpers.in_bundle?
            raise "Must be in a Bundler bundle"
          end

          require 'bundler'

          begin
            Bundler.setup
          rescue Bundler::GemNotFound
            # Do nothing yet, since we don't actually care
          end

          # Add bundler to the load path after disabling system gems
          bundler_lib = File.expand_path("../..", __FILE__)
          $LOAD_PATH.unshift(bundler_lib) unless $LOAD_PATH.include?(bundler_lib)
        end

        def create_bundle_file_task(&block)
          file "#{package_name}/local/#{short_package_name}/bundle" => "Gemfile" do
            block.call if block

            setup_bundler

            unless RUBY_VERSION == "1.9.2"
              puts "Please use Ruby 1.9.2"
              exit 1
            end

            puts "Regenerating the bundle."

            rm_rf "#{short_package_name}-pkg"
            rm_rf package_name
            rm "#{package_name}.pkg", :force => true

            begin
              # :force => true doesn't seem to work
              mv ".bundle", ".bundle.bak" rescue nil
              rm_rf "bundle"
              Bundler.with_clean_env do
                # MEGAHAX!!!!
                # When bundler is run from within a shell out, it calls Bundler.setup
                # too early. This means that the GEM_HOME gets set incorrectly and the
                # standalone bundle is not built properly
                original_rubyopt = ENV['RUBYOPT']
                begin
                  ENV['RUBYOPT'] = original_rubyopt.sub("-rbundler/setup", '')
                  sh 'bundle --standalone --without development'
                ensure
                  ENV['RUBYOPT'] = original_rubyopt
                end
              end
            rescue Exception => e
              puts e.class
              raise e
            ensure
              rm_rf ".bundle"
              # :force => true doesn't seem to work
              mv ".bundle.bak", ".bundle" rescue nil
            end

            mkdir_p "#{package_name}/local/#{short_package_name}"
            mv "bundle", "#{package_name}/local/#{short_package_name}/"

            verbose(false) do
              Dir.chdir("#{package_name}/local/#{short_package_name}/bundle/ruby/1.9.1") do
                Dir["{bin,cache,doc,specifications}"].each { |f| rm_rf f }
                Dir["**/{ext,docs,test,spec}"].each { |f| rm_rf(f) if File.directory?(f) && f !~ /maruku/i }
                Dir["**/erubis-*/doc-api"].each {|f| rm_rf(f) }
              end
            end
          end
        end

        def create_lib_file_task
          file "#{package_name}/local/#{short_package_name}/lib"

          `git ls-files -- lib`.split("\n").each do |file|
            # submodules show up as a single file
            files = File.directory?(file) ? Dir["#{file}/**/*"] : [file]

            files.each do |f|
              dest = "#{package_name}/local/#{short_package_name}/#{f}"
              file dest => f do
                verbose(false) { mkdir_p File.dirname(dest) }
                cp_r f, dest
              end
              task "#{package_name}/local/#{short_package_name}/lib" => dest
            end
          end
        end

        def create_bin_files_task
          bin_files.each do |bin_name|
            path = "#{package_name}/bin/#{bin_name}"
            file path => "bin/#{bin_name}" do
              data = File.read("bin/#{bin_name}").sub(/\A#.*/, "#!#{ruby_bin_path}") if ruby_bin_path

              mkdir_p "#{package_name}/bin"
              File.open(path, "w") { |file| file.puts data }
              File.chmod 0755, path
            end
          end
        end

        def create_resource_files_task
          resource_files.each do |resource_name|
            file "#{package_name}/local/#{short_package_name}/#{resource_name}" => resource_name do
              destdir = "#{package_name}/local/#{short_package_name}/#{File.dirname(resource_name)}"
              mkdir_p destdir
              cp_r resource_name, destdir
              target = "#{package_name}/local/#{short_package_name}/#{resource_name}"
              if File.directory?(target)
                Dir.glob(target).each{|f| File.chmod 0655 unless File.directory?(f) }
              else
                File.chmod 0644, target
              end
            end
          end
        end

        def make_pkg_tasks
          tasks = ["#{package_name}/local/#{short_package_name}/bundle",
                             "#{package_name}/local/#{short_package_name}/lib"]
          tasks += bin_files.map{|b| "#{package_name}/bin/#{b}" }
          tasks += resource_files.map{|r| "#{package_name}/local/#{short_package_name}/#{r}" }
        end

        def create_make_pkg_task
          task :make_pkg => make_pkg_tasks
        end

        def create_rm_task
          # TODO: Remove more fully
          task :rm do
            rm_rf package_name
          end
        end

    end
  end
end
