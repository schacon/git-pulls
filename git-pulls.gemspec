$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name              = "git-pulls"
  s.version           = "0.1.0"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "facilitates github pull requests"
  s.homepage          = "http://github.com/schacon/git-pulls"
  s.email             = "schacon@gmail.com"
  s.authors           = [ "Scott Chacon" ]
  s.has_rdoc          = false

  s.files             = %w( LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")

  s.executables       = %w( git-pulls )

  s.add_runtime_dependency     'json'
  s.add_runtime_dependency     'httparty'

  s.description       = <<desc
  git-pulls facilitates github pull requests.
desc
end
