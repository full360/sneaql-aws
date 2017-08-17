Gem::Specification.new do |s|
  s.name        = 'sneaql-aws'
  s.version     = '0.0.3'
  s.date        = '2017-08-15'
  s.summary     = "sneaql extensions to interact with AWS"
  s.description = "provides extensions to sneaql allowing interaction with AWS"
  s.authors     = ["jeremy winters"]
  s.email       = 'jeremy.winters@full360.com'
  s.files       = ["lib/sneaql-aws.rb"]
  
  s.homepage    = 'https://www.full360.com'
  s.license     = 'MIT'
  s.platform = 'java'
  
  s.add_runtime_dependency 'logger','~>1.2'
  s.add_development_dependency 'minitest','~>5.9'
  s.add_runtime_dependency 'git','~>1.3'
  s.add_runtime_dependency 'aws-sdk','~>2.6'
  s.required_ruby_version = '>= 2.0' 
end
