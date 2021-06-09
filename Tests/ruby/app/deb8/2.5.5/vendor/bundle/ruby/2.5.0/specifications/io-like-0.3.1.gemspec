# -*- encoding: utf-8 -*-
# stub: io-like 0.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "io-like".freeze
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jeremy Bopp".freeze, "Jarred Holman".freeze, "Grant Gardner".freeze, "Jordan Pickwell".freeze]
  s.date = "2020-02-09"
  s.description = "The IO::Like module provides all of the methods of typical IO implementations\nsuch as File; most importantly the read, write, and seek series of methods.  A\nclass which includes IO::Like needs to provide only a few methods in order to\nenable the higher level methods.  Buffering is automatically provided by default\nfor the methods which normally provide it in IO.\n".freeze
  s.email = ["jeremy@bopp.net".freeze, "jarred.holman@gmail.com".freeze, "grant@lastweekend.com.au".freeze, "jpickwell@users.noreply.github.com".freeze]
  s.extra_rdoc_files = ["LICENSE".freeze, "LICENSE-rubyspec".freeze, "NEWS.md".freeze, "README.md".freeze]
  s.files = ["LICENSE".freeze, "LICENSE-rubyspec".freeze, "NEWS.md".freeze, "README.md".freeze]
  s.homepage = "http://github.com/javanthropus/io-like".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--title".freeze, "IO::Like Documentation".freeze, "--charset".freeze, "utf-8".freeze, "--line-numbers".freeze, "--inline-source".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.1".freeze)
  s.rubygems_version = "2.7.6.2".freeze
  s.summary = "A module which provides the functionality of an IO object to any including class which provides a couple of simple methods.".freeze

  s.installed_by_version = "2.7.6.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>.freeze, ["~> 10.3"])
      s.add_development_dependency(%q<mspec>.freeze, ["~> 1.5"])
      s.add_development_dependency(%q<yard>.freeze, ["~> 0.8"])
      s.add_development_dependency(%q<yard-redcarpet-ext>.freeze, ["~> 0.0"])
      s.add_development_dependency(%q<github-markup>.freeze, ["~> 1.2"])
    else
      s.add_dependency(%q<rake>.freeze, ["~> 10.3"])
      s.add_dependency(%q<mspec>.freeze, ["~> 1.5"])
      s.add_dependency(%q<yard>.freeze, ["~> 0.8"])
      s.add_dependency(%q<yard-redcarpet-ext>.freeze, ["~> 0.0"])
      s.add_dependency(%q<github-markup>.freeze, ["~> 1.2"])
    end
  else
    s.add_dependency(%q<rake>.freeze, ["~> 10.3"])
    s.add_dependency(%q<mspec>.freeze, ["~> 1.5"])
    s.add_dependency(%q<yard>.freeze, ["~> 0.8"])
    s.add_dependency(%q<yard-redcarpet-ext>.freeze, ["~> 0.0"])
    s.add_dependency(%q<github-markup>.freeze, ["~> 1.2"])
  end
end
