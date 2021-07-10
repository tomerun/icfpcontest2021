require "http/client"

headers = HTTP::Headers.new
headers["Authorization"] = "Bearer #{ENV["API_KEY"]}"
headers["Content-Type"] = "application/json"
body = STDIN.gets_to_end
HTTP::Client.post("https://poses.live/api/problems/#{ENV["PROBLEM_ID"]}/solutions", headers: headers, body: body) do |res|
  puts res.status
  puts res.headers
  puts res.body
end
