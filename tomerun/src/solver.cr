require "json"
START_TIME        = Time.utc.to_unix_ms
TL_WHOLE          = 1000000
TL_SINGLE         =    2000
RESULT_EMPTY      = Result.new(Array(Point).new, 1i64 << 60)
RND               = XorShift.new
PLACE_PENA        =    10
VERTEX_BONUS      =     0
SEARCH_COUNT      =    30
MAX_IMPROVE_CNT   =   100
IMPROVE_TL        = 10000
INITIAL_COOLER    =   0.2
FINAL_COOLER      =   2.0
INITIAL_PENA_COEF =   0.5
FINAL_PENA_COEF   =  50.0

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

class UnionFind
  def initialize(size : Int32)
    @root = Array(Int32).new(size, -1)
  end

  def union(i, j)
    a = root(i)
    b = root(j)
    if a != b
      @root[a] += @root[b]
      @root[b] = a
    end
  end

  def find(i, j)
    root(i) == root(j)
  end

  def root(i)
    return i if @root[i] < 0
    @root[i] = root(@root[i])
  end

  def size(i)
    -@root[root(i)]
  end
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
  if !ARGV.empty?
    best_result = RESULT_EMPTY
    orig_vs = JSON.parse(File.read_lines(ARGV[0]).join("\n"))["vertices"].as_a
    vs = orig_vs.map { |e| e.as_a.map { |v| v.as_i } }.map { |e| {e[1] - min_y, e[0] - min_x} }
    dislike = 0i64
    (hole.size - 1).times do |i|
      dislike += vs.min_of { |v| distance(hole[i], v) }
    end
    debug(dislike)
    result = Result.new(vs, dislike)
    MAX_IMPROVE_CNT.times do
      res = solver.improve(result)
      if res.dislike < best_result.dislike
        STDERR.puts "dislike:#{res.dislike}"
        STDERR.puts res.vertices.map { |p| [p[1] + min_x, p[0] + min_y] }.to_json
        best_result = res
      end
    end
    result = best_result
  else
    result = solver.solve
  end
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

  def initialize(
    epsilon : Int64, @max_y : Int32, @max_x : Int32,
    @background : Array(Array(Bool)), @eval_pos : Array(Array(Int32))
  )
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
      bonus_y = RND.next_int & 1
      bonus_x = RND.next_int & 1
      shuffle(@ps)
      @ps.sort_by! do |p|
        @eval_pos[p[0]][p[1]] - ((p[0] & 1) == bonus_y && (p[1] & 1) == bonus_x ? 40 : 0)
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

def from_rhs(p1, p2, p3)
  dx1 = p2[1] - p1[1]
  dy1 = p2[0] - p1[0]
  dx2 = p3[1] - p1[1]
  dy2 = p3[0] - p1[0]
  s = dx1 * dy2 - dy1 * dx2
  return s < 0
end

def from_rhs_v(p1, p2, p3, p4)
  a1 = -Math.atan2(p1[0] - p2[0], p1[1] - p2[1])
  a2 = -Math.atan2(p3[0] - p2[0], p3[1] - p2[1])
  a3 = -Math.atan2(p4[0] - p2[0], p4[1] - p2[1])
  if a1 < a2
    return a3 < a1 || a2 < a3
  else
    return a2 < a3 && a3 < a1
  end
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
  @best_result : Result
  @eval_pos : Array(Array(Int32))
  @max_y : Int32
  @max_x : Int32
  @global_best : Int32

  def initialize(@hole : Array(Point), @graph : Array(Array(Tuple(Int32, Int32))), @epsilon : Int64)
    if ENV.has_key?("SEED")
      @global_best = File.read_lines("global_best.txt")[ENV["SEED"].to_i - 1].to_i
    else
      @global_best = 0
    end
    @n = @graph.size
    @h = @hole.size
    @tl = 0i64
    @hole << @hole[0]
    @max_y = @hole.max_of { |p| p[0] }
    @max_x = @hole.max_of { |p| p[1] }
    @eval_pos = Array.new(@max_y + 1) { Array.new(@max_x + 1, 0) }
    @used = Array.new(@n, false)
    @pos = Array.new(@n, {0, 0})
    @best_result = RESULT_EMPTY
    @inside = Array.new(@max_y + 1) { Array.new(@max_x + 1, false) }
    @search_order = [] of Int32
    @fast_back_to = Array(Int32).new(@n, -1)
    @back_to = -1
    @cooler = 1.0
    @shortest = Array(Array(Float64)).new(@n) { Array.new(@n, 1e9) }
    @n.times do |i|
      @shortest[i][i] = 0.0
      @graph[i].each do |adj|
        @shortest[i][adj[0]] = ((adj[1] * (1 + @epsilon / 1000000))) ** 0.5
      end
    end
    @n.times do |i|
      @n.times do |j|
        @n.times do |k|
          @shortest[j][k] = {@shortest[j][k], @shortest[j][i] + @shortest[i][k]}.min
        end
      end
    end
    @n.times do |i|
      @n.times do |j|
        @shortest[i][j] *= @shortest[i][j]
      end
    end
    0.upto(@max_y) do |y|
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
    @h.times do |i|
      change_eval_pos(@hole[i][0], @hole[i][1], VERTEX_BONUS, -1)
    end
    @cand_pos = Array.new(@n) { |i| Candidates.new(@epsilon, @max_y, @max_x, @inside, @eval_pos) }
  end

  def solve
    cands_triple = [] of Tuple(Int32, Int32, Int32, Int32) # (v1, v2, v3, vh) : vertices(v1-v2-v3) => (vh-vh+1-vh+2)
    cands_pair = [] of Tuple(Int32, Int32, Int32)          # (v1, v2, vh) : vertices(v1, v2) => hole(vh, vh+1)
    cands_single = [] of Tuple(Int32, Int32)               # (v1, vh) : vertices(v1) => hole(vh)
    @h.times do |i|
      dh = distance(@hole[i], @hole[i + 1])
      dh2 = distance(@hole[i + 1], @hole[i == @h - 1 ? 1 : i + 2])
      @n.times do |j|
        cands_single << {j, i}
        @graph[j].each do |e|
          if dh == e[1]
            cands_pair << {j, e[0], i}
            @graph[e[0]].each do |e2|
              if e2[0] != j && e2[1] == dh2
                cands_triple << {j, e[0], e2[0], i}
              end
            end
          end
        end
      end
    end
    best_results = [] of Result
    shuffle(cands_triple)
    cands_triple.each do |c|
      @best_result = RESULT_EMPTY
      @tl = Time.utc.to_unix_ms - START_TIME + TL_SINGLE
      solve_with_vertex([c[0], c[1], c[2]], c[-1])
      if @best_result.dislike == @global_best
        best_results = [@best_result]
        break
      end
      if @best_result != RESULT_EMPTY
        best_results << @best_result
      end
      break if elapsed_ms > TL_WHOLE * 2 // 3
    end
    shuffle(cands_pair)
    cands_pair.each do |c|
      @best_result = RESULT_EMPTY
      @tl = Time.utc.to_unix_ms - START_TIME + TL_SINGLE
      solve_with_vertex([c[0], c[1]], c[-1])
      if @best_result.dislike == @global_best
        best_results = [@best_result]
        break
      end
      if @best_result != RESULT_EMPTY
        best_results << @best_result
      end
      break if elapsed_ms > TL_WHOLE * 2 // 3
    end
    if @best_result.dislike > @global_best && elapsed_ms < TL_WHOLE
      shuffle(cands_single)
      cands_single.each do |c|
        @best_result = RESULT_EMPTY
        @tl = Time.utc.to_unix_ms - START_TIME + TL_SINGLE
        solve_with_vertex([c[0]], c[-1])
        if @best_result.dislike == @global_best
          best_results = [@best_result]
          break
        end
        if @best_result != RESULT_EMPTY
          best_results << @best_result
        end
        break if elapsed_ms > TL_WHOLE
      end
    end
    if @best_result.dislike > @global_best && elapsed_ms < TL_WHOLE
      cand_pos = Array(Point).new
      0.upto(@max_y) do |y|
        0.upto(@max_x) do |x|
          if @inside[y][x]
            cand_pos << {y, x}
          end
        end
      end
      while true
        @best_result = RESULT_EMPTY
        @tl = Time.utc.to_unix_ms - START_TIME + TL_SINGLE
        start_pos = cand_pos[RND.next_int(cand_pos.size).to_i]
        start_v = RND.next_int(@n).to_i
        solve_with_pos(start_v, start_pos)
        if @best_result.dislike == @global_best
          best_results = [@best_result]
          break
        end
        if @best_result != RESULT_EMPTY
          best_results << @best_result
        end
        break if elapsed_ms > TL_WHOLE
      end
    end
    if best_results.empty?
      return RESULT_EMPTY
    end
    if best_results[0].dislike > @global_best
      best_results.sort_by! { |r| r.dislike }
      {MAX_IMPROVE_CNT, best_results.size}.min.times do |i|
        res = improve(best_results[i])
        if res.dislike < @best_result.dislike
          @best_result = res
          break if res.dislike == @global_best
        end
      end
    end
    return @best_result
  end

  def solve_with_vertex(vs, hi)
    @cand_pos.each do |c|
      c.clear
    end
    @used.fill(false)
    debug("solve_with #{vs} #{hi}")
    vs.size.times do |i|
      if !put(vs[i], @hole[(hi + i) % @h][0], @hole[(hi + i) % @h][1])
        (i - 1).downto(0) do |j|
          revert(vs[j])
        end
        return
      end
    end
    @search_order.clear
    @search_order.concat(vs)
    create_search_order0()
    dfs(vs.size)
    vs.reverse.each do |v|
      revert(v)
    end
  end

  def solve_with_pos(v1, pos)
    @cand_pos.each do |c|
      c.clear
    end
    @used.fill(false)
    debug("solve_with #{v1} (#{pos[0]},#{pos[1]})")
    if !put(v1, pos[0], pos[1])
      return
    end
    @search_order.clear
    @search_order << v1
    create_search_order0()
    dfs(1)
    revert(v1)
  end

  def create_search_order0_dfs(start, visited, edges)
    qs = [[start], [] of Int32, [] of Int32]
    first = true
    while !qs.all? { |q| q.empty? }
      q = qs.find { |q| !q.empty? }.not_nil!
      cur = q.shift
      # cur = q.pop
      if first
        first = false
      else
        next if visited[cur]
        visited[cur] = true
        @search_order << cur
      end
      edges[cur].each do |e|
        next if visited[e[0]]
        qs[e[1]] << e[0]
      end
    end
  end

  def create_search_order0
    edges = Array.new(@n) do |i|
      @graph[i].map do |a|
        j = a[0]
        uf = UnionFind.new(@n)
        @n.times do |k|
          @graph[k].each do |a2|
            l = a2[0]
            next if {k, l}.minmax == {i, j}.minmax
            uf.union(k, l)
          end
        end
        # bridge
        [j, uf.size(i) == @n ? 0 : 2]
      end
    end
    @n.times do |i|
      edges[i].each do |e|
        next if e[1] != 0
        j = e[0]
        edges[i].each do |e1|
          next if e1[1] != 0 || e1[0] == j
          edges[j].each do |e2|
            next if e2[1] != 0 || e2[0] == i
            uf = UnionFind.new(@n)
            @n.times do |k|
              @graph[k].each do |a2|
                l = a2[0]
                next if {k, l}.minmax == {i, e1[0]}.minmax || {k, l}.minmax == {j, e2[0]}.minmax
                uf.union(k, l)
              end
            end
            if uf.size(i) != @n
              # dual-bridge
              e1[1] = 1
              e2[1] = 1
            end
          end
        end
      end
    end
    visited = Array.new(@n, false)
    @search_order.each { |v| visited[v] = true }
    @search_order.each { |v| create_search_order0_dfs(v, visited, edges) }
    # puts @search_order
    # exit
    @back_to = -1
  end

  def create_search_order
    visited = Array.new(@n, false)
    count = Array.new(@n) { |i| @graph[i].size }
    @search_order.each do |i|
      visited[i] = true
      @graph[i].each do |adj|
        count[adj[0]] += 10000
      end
    end
    while @search_order.size < @n
      ni = @n.times.select { |i| !visited[i] }.max_by { |i| count[i] }
      @search_order << ni
      visited[ni] = true
      @graph[ni].each do |adj|
        count[adj[0]] += 10000
        @fast_back_to[adj[0]] = ni
      end
    end
    @back_to = -1
  end

  def create_search_order2
    visited = Array.new(@n, false)
    @search_order.each { |i| visited[i] = true }
    @search_order.each { |i| create_search_order_dfs(i, visited) }

    # @n.times do |i|
    #   cur = @search_order[i]
    #   @graph[cur].each do |adj|
    #     next if visited[adj[0]]
    #     visited[adj[0]] = true
    #     @search_order << adj[0]
    #   end
    # end
  end

  def create_search_order_dfs(cur, visited)
    cands = @graph[cur].select { |adj| !visited[adj[0]] }.map { |v| v[0] }
    cands.sort_by { |c| -@graph[c].size }.each do |c|
      next if visited[c]
      visited[c] = true
      @search_order << c
      create_search_order_dfs(c, visited)
    end
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
      if dislike < @best_result.dislike
        debug("dislike:#{dislike}")
        @best_result = Result.new(@pos.dup, dislike)
      end
      return true
    end
    ni = @search_order[depth]
    found = false
    {@cand_pos[ni].ps.size, SEARCH_COUNT}.min.times do |cpi|
      if elapsed_ms > @tl
        break
      end
      cp = @cand_pos[ni].ps[cpi]
      ok = true
      @graph[ni].each do |adj|
        next if !@used[adj[0]]
        if is_crossing(cp, @pos[adj[0]])
          ok = false
          break
        end
      end
      next if !ok
      0.upto(depth - 1) do |i|
        pni = @search_order[i]
        if distance(cp, @pos[pni]) > @shortest[ni][pni]
          ok = false
          break
        end
      end
      next if !ok
      if put(ni, cp[0], cp[1])
        found_child = dfs(depth + 1)
        revert(ni)
        found |= found_child
        if !found_child && @back_to != -1
          if @back_to != ni
            break
          else
            @back_to = -1
          end
        end
        if @best_result.dislike == @global_best
          break
        end
      end
    end
    if !found && @back_to == -1
      @back_to = @fast_back_to[ni]
    end
    return found
  end

  def change_eval_pos(y, x, len, diff)
    {-y, -len}.max.upto({len, @max_y - y}.min) do |my|
      len_x = len - my.abs
      {-x, -len_x}.max.upto({len_x, @max_x - x}.min) do |mx|
        @eval_pos[y + my][x + mx] += diff * (len + 1 - my.abs - mx.abs)
      end
    end
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
    end
    if ok
      change_eval_pos(y, x, PLACE_PENA, 1)
    end
    return ok
  end

  def revert(vi)
    change_eval_pos(@pos[vi][0], @pos[vi][1], PLACE_PENA, -1)
    @used[vi] = false
    @graph[vi].each do |e|
      adj, d = e
      next if @used[adj]
      @cand_pos[adj].restore
    end
  end

  def is_valid_length(actual, expected)
    return (actual - expected).abs.to_i64 * 1000000 <= @epsilon
  end

  def improve(result)
    vs = result.vertices.dup
    edges = [] of Tuple(Int32, Int32, Int32, Float64)
    eis = Array.new(@n) { [] of Int32 }
    @n.times do |i|
      @graph[i].each do |adj|
        if i < adj[0]
          eis[i] << edges.size
          eis[adj[0]] << edges.size
          edges << {i, adj[0], adj[1], 0.0}
        end
      end
    end

    score = result.dislike
    nearest_vi = Array.new(@h, 0)
    nearest_d = Array.new(@h, 1 << 30)
    @h.times do |i|
      @n.times do |vi|
        d = distance(@hole[i], vs[vi])
        if d < nearest_d[i]
          nearest_d[i] = d
          nearest_vi[i] = vi
        end
      end
    end
    @cooler = INITIAL_COOLER
    pena_coef = INITIAL_PENA_COEF
    sum_ratio_pena = 0.0
    start_time = elapsed_ms
    tl = IMPROVE_TL
    turn = 0
    inv_eps = 1000000 / (@epsilon + 1)
    while true
      turn += 1
      if (turn & 0x3FFF) == 0
        elapsed = elapsed_ms - start_time
        if elapsed > tl
          debug("turn:#{turn}")
          break
        end
        time_ratio = elapsed / tl
        @cooler = Math.exp((1.0 - time_ratio) * Math.log(INITIAL_COOLER) + time_ratio * Math.log(FINAL_COOLER))
        pena_coef = (FINAL_PENA_COEF - INITIAL_PENA_COEF) * time_ratio + INITIAL_PENA_COEF
        score -= sum_ratio_pena
        old_sum_ratio_pena = sum_ratio_pena
        sum_ratio_pena = 0.0
        edges.each do |edge|
          v1, v2, ed, pena = edge
          ad = distance(vs[v1], vs[v2])
          if (ad - ed).abs.to_i64 * 1000000 <= @epsilon * ed
            next
          end
          ratio = ad / ed
          ex = (ratio - 1).abs * inv_eps
          sum_ratio_pena += ex ** 4
        end
        sum_ratio_pena *= pena_coef
        score += sum_ratio_pena
        debug("turn:#{turn} cooler:#{@cooler} pena:#{old_sum_ratio_pena}->#{sum_ratio_pena}")
      end
      vi = RND.next_int(@n)
      # my = 0.0
      # mx = 0.0
      # @graph[vi].each do |adj|
      #   vi2 = adj[0]
      #   ed = adj[1]
      #   rd = distance(vs[vi], vs[vi2])
      #   dy = vs[vi2][0] - vs[vi][0]
      #   dx = vs[vi2][1] - vs[vi][1]
      #   invnorm = 1.0 / Math.sqrt(dy ** 2 + dx ** 2)
      #   ratio = rd / ed
      #   rdiff = ((ratio - 1).abs * inv_eps) ** 3
      #   myi = dy * invnorm * (rdiff + (RND.next_double * 0.2 - 0.1))
      #   mxi = dx * invnorm * (rdiff + (RND.next_double * 0.2 - 0.1))
      #   if ratio < 1
      #     myi *= -1
      #     mxi *= -1
      #   end
      #   angle = ((RND.next_double * 1.5)) * ((RND.next_int & 1).to_i32 * 2 - 1)
      #   cos = Math.cos(angle)
      #   sin = Math.sin(angle)
      #   myi, mxi = myi * cos + mxi * sin, -myi * sin + mxi * cos
      #   my += myi
      #   mx += mxi
      # end
      # my = (my + 0.5).floor.clamp(-3, 3)
      # mx = (mx + 0.5).floor.clamp(-3, 3)
      my = RND.next_int(3) - 1
      mx = RND.next_int(3) - 1
      if my == 0 && mx == 0
        if (RND.next_int & 1) == 0
          my += RND.next_int(2) * 2 - 1
        else
          mx += RND.next_int(2) * 2 - 1
        end
      end
      ny = (vs[vi][0] + my.to_i).clamp(0, @max_y)
      nx = (vs[vi][1] + mx.to_i).clamp(0, @max_x)
      if !@inside[ny][nx]
        next
      end
      if {ny, nx} == vs[vi]
        next
      end
      # debug("#{vs[vi]} -> #{{ny, nx}}")
      ok = true
      @graph[vi].each do |adj|
        if is_crossing({ny, nx}, vs[adj[0]])
          ok = false
          break
        end
      end
      if !ok
        next
      end
      diff_score = 0
      op = vs[vi]
      vs[vi] = {ny, nx}
      @h.times do |i|
        if nearest_vi[i] == vi
          nd = @n.times.min_of { |j| distance(@hole[i], vs[j]) }
          diff_score += nd - nearest_d[i]
        else
          nd = distance(@hole[i], vs[vi])
          if nd < nearest_d[i]
            diff_score += nd - nearest_d[i]
          end
        end
      end
      diff_pena = 0.0
      eis[vi].each do |ei|
        v1, v2, ed, prev_pena = edges[ei]
        diff_pena -= prev_pena
        ad = distance(vs[v1], vs[v2])
        if (ad - ed).abs.to_i64 * 1000000 <= @epsilon * ed
          next
        end
        ratio = ad / ed
        ex = (ratio - 1).abs * inv_eps
        diff_pena += ex ** 4
      end
      diff_pena *= pena_coef
      diff_score += diff_pena
      if !accept(diff_score)
        vs[vi] = op
        next
      end
      sum_ratio_pena += diff_pena
      # debug("turn:#{turn} diff_score:#{diff_score} score:#{score} ratio_pena:#{sum_ratio_pena} #{op}->#{vs[vi]}")
      score += diff_score
      if (score + 0.5).to_i < result.dislike && sum_ratio_pena.abs <= 1e-7
        debug("turn:#{turn} best_score:#{(score + 0.5).to_i}")
        result = Result.new(vs.dup, (score + 0.5).to_i64)
      end
      eis[vi].each do |ei|
        v1, v2, ed, prev_pena = edges[ei]
        ad = distance(vs[v1], vs[v2])
        if (ad - ed).abs.to_i64 * 1000000 <= @epsilon * ed
          new_pena = 0.0
        else
          ratio = ad / ed
          ex = (ratio - 1).abs * inv_eps
          new_pena = ex ** 4
        end
        edges[ei] = {v1, v2, ed, new_pena}
      end
      @h.times do |i|
        if nearest_vi[i] == vi
          nearest_d[i] = 1 << 30
          @n.times do |j|
            d = distance(@hole[i], vs[j])
            if d < nearest_d[i]
              nearest_d[i] = d
              nearest_vi[i] = j
            end
          end
        else
          nd = distance(@hole[i], vs[vi])
          if nd < nearest_d[i]
            nearest_d[i] = nd
            nearest_vi[i] = vi
          end
        end
      end
    end
    return result
  end

  def accept(diff)
    return true if diff <= 0
    v = -diff * @cooler
    return false if v < -10
    return RND.next_double < Math.exp(-v)
  end

  def is_crossing(p1, p2)
    y1, x1 = p1
    y2, x2 = p2
    miny, maxy = {y1, y2}.minmax
    minx, maxx = {x1, x2}.minmax
    dx0 = x2 - x1
    dy0 = y2 - y1
    @h.times do |hi|
      y3, x3 = @hole[hi]
      y4, x4 = @hole[hi + 1]
      if maxy < {y3, y4}.min || {y3, y4}.max < miny || maxx < {x3, x4}.min || {x3, x4}.max < minx
        next
      end
      v1 = (dx0 * (y3 - y1) + dy0 * (x1 - x3)).to_i64
      v2 = (dx0 * (y4 - y1) + dy0 * (x1 - x4)).to_i64
      v3 = ((x3 - x4) * (y1 - y3) + (y3 - y4) * (x3 - x1)).to_i64
      v4 = ((x3 - x4) * (y2 - y3) + (y3 - y4) * (x3 - x2)).to_i64
      if v1 * v2 < 0 && v3 * v4 < 0
        return true
      end
      ph = @hole[hi == 0 ? @h - 1 : hi - 1]
      if p1 == @hole[hi]
        if from_rhs_v(ph, @hole[hi], @hole[hi + 1], p2)
          return true
        end
      elsif p1 != @hole[hi + 1] && v3 == 0 # p1 is on (@hole[hi]-@hole[hi+1])
        if from_rhs(@hole[hi], @hole[hi + 1], p2)
          return true
        end
      end
      if p2 == @hole[hi]
        if from_rhs_v(ph, @hole[hi], @hole[hi + 1], p1)
          return true
        end
      elsif p2 != @hole[hi + 1] && v4 == 0 # p2 is on (@hole[hi]-@hole[hi+1])
        if from_rhs(@hole[hi], @hole[hi + 1], p1)
          return true
        end
      end
      if v1 == 0
        dot = dx0 * (x3 - x1) + dy0 * (y3 - y1)
        if dot > 0 && distance(p1, @hole[hi]) < distance(p1, p2)
          # @hole[hi] is on (p1-p2)
          if from_rhs_v(ph, @hole[hi], @hole[hi + 1], p2)
            return true
          end
        end
      end
    end
    return false
  end
end
