# frozen_string_literal: true

require_relative 'lib/censorius/version'

Gem::Specification.new do |spec|
  spec.name          = 'censorius'
  spec.version       = Censorius::VERSION
  spec.authors       = ['Igor Makarov']
  spec.email         = ['igormaka@gmail.com']

  spec.summary       = 'A PBX UUID generator to end all generators.'
  spec.description   = 'PBX Delendare Est.'
  spec.homepage      = 'https://github.com/igor-makarov/censorius'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.4.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/igor-makarov/censorius'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = %w[README.md] + Dir['lib/**/*.rb']

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'xcodeproj', '>= 1.20.0', '~> 1'
end
