require "json"

Path="../problems"
N=106
1.upto(N){|n|
	File.open(Path+"/%04d.json" % n) do |file|
		hash=JSON.load(file)
		v=hash["hole"].size
		k=hash["figure"]["vertices"].size
		m=hash["figure"]["edges"].size
		File.open("data/%04d.txt" % n,"w") do |out|
			out.puts("#{v} #{k} #{m} #{hash["epsilon"]}")
			v.times{|i|
				out.puts("#{hash["hole"][i][0]} #{hash["hole"][i][1]}")
			}
			k.times{|i|
				out.puts("#{hash["figure"]["vertices"][i][0]} #{hash["figure"]["vertices"][i][1]}")
			}
			m.times{|i|
				out.puts("#{hash["figure"]["edges"][i][0]} #{hash["figure"]["edges"][i][1]}")
			}
		end
	end
}