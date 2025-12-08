# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'chess_engine_rb'
  spec.version       = '0.1.0'
  spec.authors       = ['nadi726']
  spec.email         = ['16650084+nadi726@users.noreply.github.com']

  spec.summary       = 'A UI-agnostic, event-driven, mostly-immutable chess engine written in pure Ruby.'
  spec.description = begin
    File.open(File.join(__dir__, 'README.md')) do |readme|
      readme.gets # heading
      content = []
      readme.each_line do |line|
        break if line.start_with?('#')

        content << line
      end
      content.join
    end
  rescue StandardError
    spec.summary
  end

  spec.homepage      = 'https://github.com/nadi726/ruby-chess-engine'
  spec.license       = 'MIT'

  spec.platform = Gem::Platform::RUBY
  spec.files         = Dir['lib/**/*', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.required_ruby_version = '>=3.4.1'
  spec.add_dependency 'immutable-ruby', '~>0.2.0'
  spec.add_dependency 'wholeable', '~> 1.4'
end
