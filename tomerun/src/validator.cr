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
  return v1.sign * v2.sign < 0 && v3.sign * v4.sign < 0
end

def is_inside(x, y, hole)
  ok = false
  count = 0
  hole.size.times do |i|
    h1 = hole[i]
    h2 = hole[i == hole.size - 1 ? 0 : i + 1]
    dx1 = h1[0] - x
    dy1 = h1[1] - y
    dx2 = h2[0] - x
    dy2 = h2[1] - y
    if dx1 == 0 && dy1 == 0 || dx2 == 0 && dy2 == 0
      return true # on a vertex
    end
    dot = dx1 * dx2 + dy1 * dy2
    if dot < 0 && dot ** 2 == (dx1 ** 2 + dy1 ** 2) * (dx2 ** 2 + dy2 ** 2)
      return true # on a segment
    end
    # add small purturbation to avoid degeneration problem
    if is_crossing(x, y + 0.001, -1000, y + 0.001, h1[0], h1[1], h2[0], h2[1])
      count += 1
    end
  end
  return count % 2 != 0
end

def is_on_segment(p1, p2, p3)
  # p3 is on (p1-p2)?
  dx1 = p2[0] - p1[0]
  dy1 = p2[1] - p1[1]
  dx2 = p3[0] - p1[0]
  dy2 = p3[1] - p1[1]
  s = dx1 * dy2 - dy1 * dx2
  return false if s != 0
  dot = dx1 * dx2 + dy1 * dy2
  return false if dot < 0
  return distance2(p1, p3) <= distance2(p1, p2)
end

def from_rhs(p1, p2, p3)
  dx1 = p2[0] - p1[0]
  dy1 = p2[1] - p1[1]
  dx2 = p3[0] - p1[0]
  dy2 = p3[1] - p1[1]
  s = dx1 * dy2 - dy1 * dx2
  return s < 0
end

def from_rhs_v(p1, p2, p3, p4)
  a1 = -Math.atan2(p1[1] - p2[1], p1[0] - p2[0])
  a2 = -Math.atan2(p3[1] - p2[1], p3[0] - p2[0])
  a3 = -Math.atan2(p4[1] - p2[1], p4[0] - p2[0])
  if a1 < a2
    return a3 < a1 || a2 < a3
  else
    return a2 < a3 && a3 < a1
  end
end

problem = JSON.parse(File.read_lines(ARGV[0]).join("\n"))
result = JSON.parse(File.read_lines(ARGV[1]).join("\n"))

hole = conv_array_of_array_of_int(problem["hole"])
edges = conv_array_of_array_of_int(problem["figure"]["edges"])
orig_vs = conv_array_of_array_of_int(problem["figure"]["vertices"])
res_vs = conv_array_of_array_of_int(result["vertices"])
epsilon = problem["epsilon"].as_i64
if res_vs.empty?
  puts "dislike=1e100"
  exit
end
if res_vs.size != orig_vs.size
  puts "output size (#{res_vs.size}) is different with problem (#{orig_vs.size})"
  exit
end

valid = true
# distance check
edges.each do |e|
  orig_d2 = distance2(orig_vs[e[0]], orig_vs[e[1]])
  res_d2 = distance2(res_vs[e[0]], res_vs[e[1]])
  if (res_d2 - orig_d2).abs.to_i64 * 1000000 > epsilon * orig_d2
    puts "edge #{e[0]}-#{e[1]} violates distance condition: #{res_d2 / orig_d2}"
    valid = false
  end
end

# each vertex is contained in the hole?
res_vs.each do |v|
  if !is_inside(v[0], v[1], hole)
    puts "vertex (#{v[0]},#{v[1]}) is outside of the hole"
    valid = false
  end
end

# each edge of the shape is not crossing the hole?
edges.each do |e|
  p1 = res_vs[e[0]]
  p2 = res_vs[e[1]]
  dx0 = p2[0] - p1[0]
  dy0 = p2[1] - p1[1]
  ok = true
  hole.size.times do |i|
    h1 = hole[i]
    h2 = hole[i == hole.size - 1 ? 0 : i + 1]
    if is_crossing(p1[0], p1[1], p2[0], p2[1], h1[0], h1[1], h2[0], h2[1])
      ok = false
      break
    end
    if p1 == h1
      if from_rhs_v(hole[i - 1], h1, h2, p2)
        puts "1 #{hole[i - 1]} #{h1} #{h2} #{p2}"
        ok = false
        break
      end
    elsif p1 != h2 && is_on_segment(h1, h2, p1)
      if from_rhs(h1, h2, p2)
        puts "3 #{h1} #{h2} #{p2}"
        ok = false
        break
      end
    end
    if p2 == h1
      if from_rhs_v(hole[i - 1], h1, h2, p1)
        puts "2 #{hole[i - 1]} #{h1} #{h2} #{p1}"
        ok = false
        break
      end
    elsif p2 != h2 && is_on_segment(h1, h2, p2)
      if from_rhs(h1, h2, p1)
        puts "4 #{h1} #{h2} #{p1}"
        ok = false
        break
      end
    end
    if p1 != h1 && p2 != h1 && is_on_segment(p1, p2, h1) && dx0 * (h2[1] - h1[1]) - dy0 * (h2[0] - h1[0]) != 0
      if from_rhs_v(hole[i - 1], h1, h2, p2)
        puts "5 #{hole[i - 1]} #{h1} #{h2} #{p1} #{p2}"
        ok = false
        break
      end
    end

    # dist = dx0 ** 2 + dy0 ** 2
    # dot = (h1[0] - p1[0]) * dx0 + (h1[1] - p1[1]) * dy0
    # if p1 != h1 && p2 != h1 && dot ** 2 == dist * distance2(p1, h1)
    #   if dot > 0 && dist > distance2(p1, h1) || dot < 0 && dist > distance2(p2, h1)
    #     # a vertex of the hole is on the edge
    #     dx1 = h2[0] - p1[0]
    #     dy1 = h2[1] - p1[1]
    #     dx2 = hole[i - 1][0] - p1[0]
    #     dy2 = hole[i - 1][1] - p1[1]
    #     s1 = dx1 * dy0 - dy1 * dx0
    #     s2 = dx2 * dy0 - dy2 * dx0
    #     if s1 * s2 < 0
    #       puts "#{p1} #{p2} #{h1} #{h2} #{hole[i - 1]}"
    #       ok = false
    #       valid = false
    #       break
    #     end
    #   end
    # end
  end

  if !ok
    puts "edge #{e[0]}-#{e[1]} (#{res_vs[e[0]][0]},#{res_vs[e[0]][1]})-(#{res_vs[e[1]][0]},#{res_vs[e[1]][1]}) is crossing the hole"
    valid = false
  end
end

# calc score
dislike = valid ? hole.map { |h| res_vs.min_of { |v| distance2(h, v) } }.sum : "1e100"
puts "dislike=#{dislike}"
