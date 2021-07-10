require "file_utils"

best_dir = Array.new(79, "")
best_score = Array.new(best_dir.size, 1e101)
Dir.glob("../result/*") do |dir|
  next if dir.ends_with?("best")
  puts dir
  File.read_lines("#{dir}/scores.txt").each do |line|
    if line.strip =~ /(\d+) *dislike.?(.+)/
      seed = $1.to_i
      score = $2.to_f
      if score < best_score[seed]
        best_dir[seed] = dir
        best_score[seed] = score
      end
    end
  end
end
File.open("../result/best/scores.txt", "w") do |f|
  1.upto(best_dir.size - 1) do |i|
    seed = sprintf("%04d", i)
    s = best_score[i] >= 1e100 ? "1e100" : best_score[i].to_i.to_s
    f << "#{seed} dislike=#{s}\n"
    FileUtils.cp("../result/#{best_dir[i]}/#{seed}.json", "../result/best/")
  end
end
