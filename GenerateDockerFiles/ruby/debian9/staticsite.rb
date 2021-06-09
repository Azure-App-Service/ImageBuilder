require 'webrick'
options = {
    :Port => ENV["PORT"].to_i,
    :DirectoryIndex => ["hostingstart.html"],
    :DocumentRoot => '/opt/startup'
}
WEBrick::HTTPServer.new(options).start
