require "json"

def conv_array_of_array_of_int(json)
  return json.as_a.map { |p| p.as_a.map { |v| v.as_i } }
end

def distance2(p1, p2)
  return (p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2
end

def is_crossing(x1, y1, x2, y2, x3, y3, x4, y4)
  v1 = (x1 - x2) * (y3 - y1) + (y1 - y2) * (x1 - x3)
  v2 = (x1 - x2) * (y4 - y1) + (y1 - y2) * (x1 - x4)
  v3 = (x3 - x4) * (y1 - y3) + (y3 - y4) * (x3 - x1)
  v4 = (x3 - x4) * (y2 - y3) + (y3 - y4) * (x3 - x2)
  return v1 * v2 < 0 && v3 * v4 < 0
end

problem = JSON.parse(File.read_lines(ARGV[0]).join("\n"))
result = JSON.parse(File.read_lines(ARGV[1]).join("\n"))

hole = conv_array_of_array_of_int(problem["hole"])
edges = conv_array_of_array_of_int(problem["figure"]["edges"])
orig_vs = conv_array_of_array_of_int(problem["figure"]["vertices"])
res_vs = conv_array_of_array_of_int(result["vertices"])
epsilon = problem["epsilon"].as_i
if res_vs.empty?
  puts "dislike:1e100"
  exit
end

# distance check
edges.each do |e|
  orig_d2 = distance2(orig_vs[e[0]], orig_vs[e[1]])
  res_d2 = distance2(res_vs[e[0]], res_vs[e[1]])
  if (res_d2 - orig_d2).abs * 1000000 > epsilon * orig_d2
    puts "edge #{e[0]}-#{e[1]} violates distance condition: #{res_d2 / orig_d2}"
  end
end

# each vertex is contained in the hole?
res_vs.each do |v|
  sum_ang = 0.0
  ok = false
  count = 0
  hole.size.times do |i|
    h1 = hole[i]
    h2 = hole[i == hole.size - 1 ? 0 : i + 1]
    dx1 = h1[0] - v[0]
    dy1 = h1[1] - v[1]
    dx2 = h2[0] - v[0]
    dy2 = h2[1] - v[1]
    if dx1 == 0 && dy1 == 0 || dx2 == 0 && dy2 == 0
      ok = true # on a vertex
      next
    end
    dot = dx1 * dx2 + dy1 * dy2
    if dot < 0 && dot ** 2 == (dx1 ** 2 + dy1 ** 2) * (dx2 ** 2 + dy2 ** 2)
      ok = true # on a segment
      next
    end
    # add small purturbation to avoid degeneration problem
    if is_crossing(v[0], v[1] + 0.001, -1, v[1] + 0.001, h1[0], h1[1], h2[0], h2[1])
      count += 1
    end
  end
  if !ok && count % 2 == 0
    puts "vertex (#{v[0]},#{v[1]}) is outside of the hole"
  end
end

# each edge of the shape is not crossing the hole?
edges.each do |e|
  p1 = res_vs[e[0]]
  p2 = res_vs[e[1]]
  ok = true
  hole.size.times do |i|
    h1 = hole[i]
    h2 = hole[i == hole.size - 1 ? 0 : i + 1]
    if is_crossing(p1[0], p1[1], p2[0], p2[1], h1[0], h1[1], h2[0], h2[1])
      ok = false
      break
    end
  end
  if !ok
    puts "edge #{e[0]}-#{e[1]} is crossing the hole"
  end
end

# calc score
dislike = hole.map { |h| res_vs.min_of { |v| distance2(h, v) } }.sum
puts "dislike:#{dislike}"
