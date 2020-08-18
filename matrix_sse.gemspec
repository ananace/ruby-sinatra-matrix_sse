# frozen_string_literal: true

require File.join(File.expand_path('lib', __dir__), 'matrix_sse/version')

Gem::Specification.new do |spec|
  spec.name          = 'matrix_sse'
  spec.version       = MatrixSse::VERSION
  spec.authors       = ['Alexander "Ace" Olofsson']
  spec.email         = ['ace@haxalot.com']

  spec.summary       = 'Testbed for MSC2108'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/ananace/ruby-sinatra-matrix_sse'
  spec.license       = 'MIT'

  spec.extra_rdoc_files = %w[LICENSE.txt README.md]
  spec.files            = Dir['lib/**'] + spec.extra_rdoc_files

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'sinatra-contrib'

  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'matrix_sdk'
  spec.add_dependency 'sinatra'
  spec.add_dependency 'thin'
end
