# Packager

Packager is a Ruby Gem that builds one-click installer packages
of your gem for Mac OS X and Windows.

## Requirements

**Windows:** MinGW Ruby install (such as [One-Click RubyInstaller](http://rubyinstaller.org/)) and [Inno Setup](http://www.jrsoftware.org/isdl.php)

**Mac OS X:** Universal binary version of Ruby ([Learn More](https://github.com/wagenet/packager/wiki/Ruby-Universal-Binary-Installation)) and possibly the OS X Developer Tools

## Usage

In your project's Rakefile

    Packager::RakeTask.new(:pkg) do |t|
      t.package_name = "My Project"
      t.version = "1.0.0"
      t.domain = "myproject.com"
      t.bin_files = ["utility", "helper"]
      t.resource_files = ["images", "README"]
    end

## Known Issues

* Requires a git repo for your project (git ls-files is used internally)
* Limited configuration
* No installer styling options
* When uninstalling from Windows Ruby Uninstaller isn't run properly,
  though this shouldn't actually cause any problems.

## Credits

* Peter Wagenet
* Yehuda Katz
