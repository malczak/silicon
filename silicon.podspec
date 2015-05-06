Pod::Spec.new do |s|

  s.name         = "silicon"
  s.version      = "0.0.1"
  s.license      = "MIT"
  s.summary      = "DI/SL for ios"
  s.homepage     = "https://github.com/malczak/silicon" 
  
  s.author       = { "Matt" => "mateusz@malczak.info" }
  s.platform     = :ios
 
  s.source       = { :git => "https://github.com/malczak/silicon.git", :commit => "29600ac6f91244dc868f1194961236c1ceb2c920" }

  s.source_files  = "Source/**/*.{h,m}"
  s.exclude_files = "Examples","Classes/Exclude"

  s.requires_arc = true

end
