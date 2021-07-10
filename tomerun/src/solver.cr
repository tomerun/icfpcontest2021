require "json"
START_TIME   = Time.utc.to_unix_ms
TL_WHOLE     = 20000
TL_SINGLE    =  1000
RESULT_EMPTY = Result.new(Array(Point).new, 1i64 << 60)
RND          = XorShift.new

class XorShift
  TO_DOUBLE = 0.5 / (1u64 << 63)

  def initialize(@x = 123456789u64)
  end

  def next_int
    @x ^= @x << 13
    @x ^= @x >> 17
    @x ^= @x << 5
    return @x
  end

  def next_int(m)
    return (next_int % m).to_i
  end

  def next_double
    return TO_DOUBLE * next_int
  end
end

macro debug(msg)
  {% if flag?(:local) %}
    STDERR.puts({{msg}})
  {% end %}
end

macro debugf(format_string, *args)
  {% if flag?(:local) %}
    STDERR.printf({{format_string}}, {{*args}})
  {% end %}
end

def elapsed_ms
  return Time.utc.to_unix_ms - START_TIME
end

alias Point = Tuple(Int32, Int32)

main

def main
  input = JSON.parse(STDIN.gets_to_end)
  hole = input["hole"].as_a.map do |v|
    a = v.as_a.map { |p| p.as_i }
    {a[1], a[0]} # [y, x]
  end
  min_y = hole.min_of { |p| p[0] }
  min_x = hole.min_of { |p| p[1] }
  hole = hole.map { |p| {p[0] - min_y, p[1] - min_x} }
  edges = input["figure"]["edges"].as_a.map do |v|
    a = v.as_a.map { |p| p.as_i }
    {a[0], a[1]}
  end
  vertices = input["figure"]["vertices"].as_a.map do |v|
    a = v.as_a.map { |p| p.as_i }
    {a[1], a[0]}
  end
  epsilon = input["epsilon"].as_i64
  graph = Array.new(vertices.size) { [] of Tuple(Int32, Int32) }
  edges.each do |e|
    dist = distance(vertices[e[0]], vertices[e[1]])
    graph[e[0]] << {e[1], dist}
    graph[e[1]] << {e[0], dist}
  end
  solver = Solver.new(hole, graph, epsilon)
  result = solver.solve
  # debug("dislike:#{result.dislike}")
  puts({"vertices" => result.vertices.map { |p| [p[1] + min_x, p[0] + min_y] }}.to_json)
end

class Result
  getter :vertices, :dislike

  def initialize(@vertices : Array(Point), @dislike : Int64)
  end
end

class Candidates
  getter :ps
  @eps : Float64

  def initialize(epsilon : Int64, @max_y : Int32, @max_x : Int32, @background : Array(Array(Bool)), @i : Int32)
    @init = false
    @ps = [] of Point
    @stack = Array(Tuple(Bool, Array(Point))).new
    @eps = epsilon / 1000000
  end

  def set(y, x, d)
    min_d2 = ((1 - @eps) * d).ceil.to_i
    max_d2 = ((1 + @eps) * d).floor.to_i
    if @init
      @ps.select! do |p|
        dist = distance(p, {y, x})
        min_d2 <= dist && dist <= max_d2
      end
    else
      @init = true
      min_y = {0, (y - Math.sqrt(max_d2)).ceil.to_i}.max
      max_y = {@max_y, (y + Math.sqrt(max_d2)).floor.to_i}.min
      min_y.upto(max_y) do |yn|
        min_dx2 = min_d2 - (yn - y) ** 2
        max_dx = Math.sqrt(max_d2 - (yn - y) ** 2).floor.to_i
        if min_dx2 <= 0
          {0, x - max_dx}.max.upto({@max_x, x + max_dx}.min) do |xn|
            @ps << {yn, xn} if @background[yn][xn]
          end
        else
          min_dx = Math.sqrt(min_dx2).ceil.to_i
          {0, x - max_dx}.max.upto(x - min_dx) do |xn|
            @ps << {yn, xn} if @background[yn][xn]
          end
          (x + min_dx).upto({@max_x, x + max_dx}.min) do |xn|
            @ps << {yn, xn} if @background[yn][xn]
          end
        end
      end
      shuffle(@ps)
      @ps.sort_by! do |p|
        sum = 0
        if p[0] == 0 || !@background[p[0] - 1][p[1]]
          sum -= 1
        end
        if p[0] == @max_y || !@background[p[0] + 1][p[1]]
          sum -= 1
        end
        if p[1] == 0 || !@background[p[0]][p[1] - 1]
          sum -= 1
        end
        if p[1] == @max_x || !@background[p[0]][p[1] + 1]
          sum -= 1
        end
        sum
      end
    end
  end

  def check
    @stack << {@init, @ps.dup}
  end

  def restore
    @init, @ps = @stack.pop
  end

  def clear
    @init = false
    @ps.clear
    @stack.clear
  end
end

def distance(p1, p2)
  return (p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2
end

def shuffle(ar)
  (ar.size - 1).times do |i|
    pos = RND.next_int(ar.size - i).to_i + i
    ar[i], ar[pos] = ar[pos], ar[i]
  end
end

class Solver
  @n : Int32
  @h : Int32
  @inside : Array(Array(Bool))
  @cand_pos : Array(Candidates)
  @used : Array(Bool)
  @pos : Array(Point)

  def initialize(@hole : Array(Point), @graph : Array(Array(Tuple(Int32, Int32))), @epsilon : Int64)
    @n = @graph.size
    @h = @hole.size
    @tl = 0i64
    @hole << @hole[0]
    max_y = @hole.max_of { |p| p[0] }
    max_x = @hole.max_of { |p| p[1] }
    @used = Array.new(@n, false)
    @pos = Array.new(@n, {0, 0})
    @inside = Array.new(max_y + 1) { Array.new(max_x + 1, false) }
    0.upto(max_y) do |y|
      cp = [] of Float64
      @h.times do |i|
        dy1 = @hole[i][0] - y
        dy2 = @hole[i + 1][0] - y
        next if dy1 * dy2 > 0
        if dy1 * dy2 < 0
          cp << @hole[i][1] + (@hole[i + 1][1] - @hole[i][1]) * (y - @hole[i][0]) / (@hole[i + 1][0] - @hole[i][0])
        else
          if dy1 == 0 && dy2 == 0
            lo, hi = {@hole[i][1], @hole[i + 1][1]}.minmax
            lo.upto(hi) do |x|
              @inside[y][x] = true
            end
          elsif dy1 == 0
            @inside[y][@hole[i][1]] = true
            pi = i - 1
            while true
              dy0 = @hole[pi][0] - y
              break if dy0 != 0
              pi -= 1
            end
            if dy0 * dy2 < 0
              cp << @hole[i][1].to_f
            end
          end
        end
      end
      cp = cp.uniq.sort
      0.step(to: cp.size - 1, by: 2) do |i|
        cp[i].ceil.to_i.upto(cp[i + 1].floor.to_i) do |x|
          @inside[y][x] = true
        end
      end
    end
    # puts @inside.map { |row| row.map { |v| v ? "1" : "0" }.join }.join("\n")
    @cand_pos = Array.new(@n) { |i| Candidates.new(@epsilon, max_y, max_x, @inside, i) }
  end

  def solve
    cands_pair = [] of Tuple(Int32, Int32, Int32) # (v1, v2, vh) : vertices(v1, v2) => hole(vh, vh+1)
    cands_single = [] of Tuple(Int32, Int32)      # (v1, vh) : vertices(v1) => hole(vh)
    @h.times do |i|
      dh = distance(@hole[i], @hole[i + 1])
      @n.times do |j|
        cands_single << {j, i}
        @graph[j].each do |e|
          if dh == e[1]
            cands_pair << {j, e[0], i}
          end
        end
      end
    end
    best_result = RESULT_EMPTY
    shuffle(cands_pair)
    cands_pair.each do |c|
      @tl += TL_SINGLE
      result = solve_with(*c)
      if result.dislike < best_result.dislike
        best_result = result
        if best_result.dislike == 0
          break
        end
      end
      break if elapsed_ms > TL_WHOLE
    end
    if best_result.dislike > 0 && elapsed_ms < TL_WHOLE
      shuffle(cands_single)
      cands_single.each do |c|
        @tl += TL_SINGLE
        result = solve_with(*c)
        if result.dislike < best_result.dislike
          best_result = result
          if best_result.dislike == 0
            break
          end
        end
        break if elapsed_ms > TL_WHOLE
      end
    end
    return best_result
  end

  def solve_with(v1, v2, hi)
    @cand_pos.each { |c| c.clear }
    @used.fill(false)
    debug("solve_with #{v1} #{v2} #{hi}")
    res = RESULT_EMPTY
    if !put(v1, @hole[hi][0], @hole[hi][1])
      return res
    end
    if !put(v2, @hole[hi + 1][0], @hole[hi + 1][1])
      return res
    end
    res = dfs(2)
    return res
  end

  def solve_with(v1, hi)
    @cand_pos.each { |c| c.clear }
    @used.fill(false)
    debug("solve_with #{v1} #{hi}")
    res = RESULT_EMPTY
    if !put(v1, @hole[hi][0], @hole[hi][1])
      return res
    end
    res = dfs(1)
    return res
  end

  def dfs(depth)
    if depth == @n
      dislike = 0i64
      @h.times do |i|
        md = 1i64 << 60
        @n.times do |j|
          md = {md, distance(@hole[i], @pos[j])}.min
        end
        dislike += md
      end
      debug("dislike:#{dislike}")
      return Result.new(@pos.dup, dislike)
    end
    best_res = RESULT_EMPTY
    if elapsed_ms > @tl
      return best_res
    end
    # TODO: select next vertex wisely
    @n.times do |i|
      next if @used[i]
      # debug("put #{i}")
      @cand_pos[i].ps.each do |cp|
        ok = true
        @graph[i].each do |adj|
          next if !@used[adj[0]]
          if is_crossing(cp, @pos[adj[0]])
            ok = false
            break
          end
        end
        next if !ok
        if put(i, cp[0], cp[1])
          # TODO: edge cross check for nonconvex hole
          res = dfs(depth + 1)
          if res.dislike < best_res.dislike
            best_res = res
            if best_res.dislike == 0
              break
            end
          end
          revert(i)
        end
      end
    end
    return best_res
  end

  def put(vi, y, x)
    @used[vi] = true
    @pos[vi] = {y, x}
    ok = true
    @graph[vi].each.with_index do |e, i|
      adj, d = e
      next if @used[adj]
      @cand_pos[adj].check
      @cand_pos[adj].set(y, x, d)
      if @cand_pos[adj].ps.empty?
        0.upto(i) do |j|
          adj = @graph[vi][j][0]
          if !@used[adj]
            @cand_pos[adj].restore
          end
        end
        ok = false
        @used[vi] = false
        break
      end
      # habit = Array.new(@inside.size) { Array.new(@inside[0].size, 0) }
      # @cand_pos[adj].ps.each do |p|
      #   habit[p[0]][p[1]] = 1
      # end
      # puts "#{vi} -> #{adj}"
      # puts habit.map { |row| row.join }.join("\n")
    end
    return ok
  end

  def revert(vi)
    @used[vi] = false
    @graph[vi].each do |e|
      adj, d = e
      next if @used[adj]
      @cand_pos[adj].restore
    end
  end

  def is_crossing(p1, p2)
    y1, x1 = p1
    y2, x2 = p2
    @h.times do |hi|
      y3, x3 = @hole[hi]
      y4, x4 = @hole[hi + 1]
      v1 = (x1 - x2) * (y3 - y1) + (y1 - y2) * (x1 - x3)
      v2 = (x1 - x2) * (y4 - y1) + (y1 - y2) * (x1 - x4)
      if v1 * v2 < 0
        v3 = (x3 - x4) * (y1 - y3) + (y3 - y4) * (x3 - x1)
        v4 = (x3 - x4) * (y2 - y3) + (y3 - y4) * (x3 - x2)
        if v3 * v4 < 0
          return true
        end
      end
    end
    return false
  end
end
