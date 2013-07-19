# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vmbox/version'

Gem::Specification.new do |spec|
  spec.name          = "tryphon-vmbox"
  spec.version       = VMBox::VERSION
  spec.authors       = ["Alban Peignier", "Florent Peyraud"]
  spec.email         = ["alban@tryphon.eu", "florent@tryphon.eu"]
  spec.description   = %q{Start, stop, reset, manage storage of QEMU/kvm virtual machines to run Tryphon Boxes}
  spec.summary       = %q{Control Tryphon Boxes VM from Ruby}
  spec.homepage      = "http://projects.tryphon.eu/projects/vmbox"
  spec.license       = "GPL 3.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "qemu"
  spec.add_runtime_dependency "json"
  spec.add_runtime_dependency "activesupport", "~> 3.2.1"

  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "rdoc"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
