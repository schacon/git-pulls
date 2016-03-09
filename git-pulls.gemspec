$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name     = "git-pulls"
  s.version  = "0.4.14"
  s.licenses = ['MIT']
  s.date     = Time.now.strftime('%Y-%m-%d')
  s.summary  = "facilitates github pull requests"
  s.homepage = "http://github.com/schacon/git-pulls"
  s.email    = "adrien.giboire@gmail.com"
  s.authors  = ["Adrien Giboire", "Scott Chacon"]

  s.files    = %w( LICENSE )
  s.files    += Dir.glob("lib/**/*")
  s.files    += Dir.glob("bin/**/*")

  s.executables = %w( git-pulls )
  s.description = "git-pulls facilitates github pull requests."

  s.add_runtime_dependency 'json', '~> 1.8', '>= 1.8.3'
  s.add_runtime_dependency 'launchy', '~> 2.4', '>= 2.4.3'
  s.add_runtime_dependency 'octokit', '~> 4.3', '>= 4.3.0'

  s.add_development_dependency 'minitest', '~> 5.8', '>= 5.8.4'
  s.add_development_dependency 'rake', '~> 11.0', '>= 11.0.1'
end
