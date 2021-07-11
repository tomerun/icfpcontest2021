require "json"

input = JSON.parse(STDIN.gets_to_end)
max_coord = (input["hole"].as_a.map { |v| v.as_a } + input["figure"]["vertices"].as_a.map { |v| v.as_a }).flatten.map { |v| v.as_i.abs }.max
bonus = input["bonuses"].as_a.map do |b|
  "#{b["bonus"]}\t#{b["problem"]}"
end.join("\t")
puts "#{max_coord}\t#{input["hole"].size}\t#{input["figure"]["edges"].size}\t#{input["figure"]["vertices"].size}\t#{input["epsilon"]}\t#{bonus}"
