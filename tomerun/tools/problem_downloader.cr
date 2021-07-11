require "http/client"

headers = HTTP::Headers.new
headers["Authorization"] = "Bearer #{ENV["API_KEY"]}"

1.upto(132) do |i|
  HTTP::Client.get("https://poses.live/api/problems/#{i}", headers: headers) do |res|
    puts res.status
    # puts res.headers
    File.open(sprintf("%04d.json", i), "w") do |f|
      res.body_io.each_line do |line|
        f.write(line.encode("UTF-8"))
      end
    end
  end
end
