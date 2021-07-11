require "http/client"
PROB_COUNT = 132

def read_scores(file_name)
  scores = Array.new(PROB_COUNT + 1, 1e100)
  File.read_lines(file_name).each do |line|
    if line.strip =~ /(\d+)\s*dislike.(.+)/
      seed = $1.to_i
      score = $2.to_f
      scores[seed] = score
    end
  end
  return scores
end

my_score = read_scores("../result/best/scores.txt")
team_score = read_scores(ARGV[0])

headers = HTTP::Headers.new
headers["Authorization"] = "Bearer #{ENV["API_KEY"]}"
headers["Content-Type"] = "application/json"

1.upto(PROB_COUNT) do |i|
  next if my_score[i] >= team_score[i]
  puts "submit #{i} #{team_score[i]} => #{my_score[i]}"
  body = File.open("../result/best/#{sprintf("%04d", i)}.json").gets_to_end
  HTTP::Client.post("https://poses.live/api/problems/#{i}/solutions", headers: headers, body: body) do |res|
    puts res.status
    puts res.headers
    puts res.body
  end
end
