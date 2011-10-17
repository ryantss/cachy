# desc 'Generate documentation'
# YARD::Rake::YardocTask.new

Jeweler::Tasks.new do |gem|
  gem.name        = "cachy"
  gem.summary     = "Ruby method cache library"
  gem.description = "A library includes a helper to cache any methods in Ruby (mostly Rails)"
  gem.author      = "Son"
  gem.email       = "son@wego.com"
  gem.homepage    = "http://www.wego.com"

  gem.files       = FileList[
    'lib/*.rb',
    'lib/*.rb',
    'tasks/*.rb',
  ]
end
