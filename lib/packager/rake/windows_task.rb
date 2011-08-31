require 'packager/rake/base_task'

module Packager
  module Rake
    class WindowsTask < BaseTask

      attr_accessor :path_constant

      def initialize(*)
        super

        @path_constant ||= "#{package_name.gsub(/\s+/,'')}Path"

        create_bundle_file_task do
          unless RbConfig::CONFIG["host_os"] =~ /mingw32/
            puts "Please use a mingw32 copy of ruby"
            exit 1
          end
        end
        create_lib_file_task
        create_bin_files_task
        create_bin_file_aliases_task
        create_resource_files_task
        create_make_pkg_task

        create_ruby_download_task
        create_iss_task
        create_pkg_task

        desc "Package for Windows"
        task :pkg => "#{package_name}.exe"

        desc "Clean and Package for Windows"
        task :clean => [:rm, :pkg]
      end

      def ruby_bin_path
        "\"%#{path_constant}%/ruby/bin/ruby.exe\" -I \"%#{path_constant}%/local/#{short_package_name}/bundle\" -r bundler/setup"
      end

      private

        def create_bin_file_aliases_task
          bin_files.each do |bin_name|
            path = "#{package_name}/bin/#{bin_name}.bat"
            file path => "bin/#{bin_name}" do
              File.open(path, "w") do |f|
                f.puts <<END
@ECHO OFF
IF NOT "%~f0" == "~f0" GOTO :WinNT
@#{ruby_bin_path} "#{bin_name}" %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO :EOF
:WinNT
@#{ruby_bin_path} "%~dpn0" %*
END
              end
              File.chmod 0755, path
            end
          end
        end

        def create_ruby_download_task
          installer_path = "#{package_name}/rubyinstaller.exe"

          task :download_ruby do
            unless File.exist?(installer_path)
              mkdir_p File.dirname(installer_path)

              puts "Downloading rubyinstaller.exe"

              require 'net/http'
              Net::HTTP.start("packager.strobeapp.com") do |http|
                File.open(installer_path, 'wb') do |f|
                  http.request_get('/rubyinstaller.exe') do |resp|
                    resp.read_body do |segment|
                      print '.'
                      f.write(segment)
                    end
                  end
                end
              end

              puts "Done"
            end
          end
        end

        def create_iss_task
          erb_path = File.join(RESOURCES_PATH, "packager.iss.erb")

          file "#{package_name}/packager.iss" do
            src = File.read erb_path
            erb = ERB.new(src)

            File.open("#{package_name}/packager.iss", "w") do |file|
              file.puts erb.result(binding)
            end
          end
        end

        def make_pkg_tasks
          super + bin_files.map{|b| "#{package_name}/bin/#{b}.bat" }
        end

        def create_pkg_task
          file "#{package_name}.exe" => [:make_pkg, :download_ruby, "#{package_name}/packager.iss"] do
            inno_dir = ENV['INNO_DIR'] || "C:\\Program Files\\Inno Setup 5\\"
            inno_dir += '\\' unless inno_dir[-1..-1] == '\\'

            puts "Compiling. This may take a while..."
            sh %{"#{inno_dir}Compil32.exe" /cc "#{package_name}\\packager.iss"}
            mv "#{package_name}/Output/setup.exe", "#{package_name}.exe"

            unless ENV['NOCLEAN']
              # Cleanup
              rm_rf package_name
            end
          end
        end

    end
  end
end
