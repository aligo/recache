$:.push File.expand_path("../lib", __FILE__)
require "recache/version"

Gem::Specification.new do |spec|
  spec.name          = "recache"
  spec.version       = Recache::VERSION
  spec.authors       = ["aligo Kang"]
  spec.email         = ["aligo_x@163.com"]

  spec.summary       = %q{Redis-based cache}
  spec.description   = %q{Redis-based cache}
  spec.license       = "MIT"

  spec.files         = Dir['./**/*'].reject { |file| file =~ /\.\/(bin|log|pkg|script|s|test|vendor|tmp)/ }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "redis"
  spec.add_runtime_dependency "connection_pool"
  spec.add_runtime_dependency "oj"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
