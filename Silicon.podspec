Pod::Spec.new do |s|

s.name         = "Silicon"
s.version      = "0.2.1"
s.license      = "MIT"
s.homepage     = "https://github.com/malczak/silicon"
s.summary      = "Simple dependency injection / service locator for swift applications."
s.author       = { "Mateusz Malczak" => "mateusz@malczak.info" }
s.source       = { :git => "https://github.com/malczak/silicon.git", :branch => "swift" }

s.platform     = :ios, "9.0"

s.source_files  = "Source/*.swift"
s.exclude_files = "Source/*Tests.swift"

s.requires_arc = true
end
