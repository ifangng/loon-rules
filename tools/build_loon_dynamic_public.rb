#!/usr/bin/env ruby
# frozen_string_literal: true

INPUT_RULE_CONF = ARGV[0] || "config/loon-rules-public.conf"
OUTPUT_LCF = ARGV[1] || "config/loon-dynamic-public.lcf"

rule_lines = File.readlines(INPUT_RULE_CONF, chomp: true)
remote_rules = []
final_policy = "DIRECT"

rule_lines.each do |line|
  s = line.strip
  next if s.empty? || s.start_with?("[")

  if s.start_with?("RULE-SET,")
    _type, url, policy = s.split(",", 3)
    tag = File.basename(url, ".list")
    remote_rules << "#{url}, policy=#{policy}, tag=#{tag}, enabled=true"
  elsif s.start_with?("FINAL,")
    final_policy = s.split(",", 2)[1].to_s.strip
  end
end

out = []
out << "# Publishable dynamic Loon config template"
out << "# Safe to publish: no node credentials here."
out << "# Node subscription should be added separately in Loon app."
out << ""
out << "[General]"
out << "bypass-system=true"
out << "skip-proxy=192.168.0.0/16,10.0.0.0/8,127.0.0.1,localhost,*.local"
out << "proxy-test-url=http://www.gstatic.com/generate_204"
out << ""
out << "[Remote Proxy]"
out << "# Keep this section empty. Add your subscriptions in Loon app."
out << ""
out << "[Remote Filter]"
out << "香港节点 = NameRegex,,FilterKey=(?i)(港|HK|Hong)"
out << "台湾节点 = NameRegex,,FilterKey=(?i)(台|TW|Taiwan)"
out << "日本节点 = NameRegex,,FilterKey=(?i)(日|JP|Japan|Tokyo|Osaka)"
out << "新加坡节点 = NameRegex,,FilterKey=(?i)(新|SG|Singapore)"
out << "美国节点 = NameRegex,,FilterKey=(?i)(美|US|USA|United States)"
out << "全球节点 = NameRegex,,FilterKey=."
out << ""
out << "[Proxy Group]"
out << "香港自动 = url-test,香港节点,url=http://www.gstatic.com/generate_204,interval=300,tolerance=50"
out << "台湾自动 = url-test,台湾节点,url=http://www.gstatic.com/generate_204,interval=300,tolerance=50"
out << "日本自动 = url-test,日本节点,url=http://www.gstatic.com/generate_204,interval=300,tolerance=50"
out << "新加坡自动 = url-test,新加坡节点,url=http://www.gstatic.com/generate_204,interval=300,tolerance=50"
out << "美国自动 = url-test,美国节点,url=http://www.gstatic.com/generate_204,interval=300,tolerance=50"
out << "自动选择 = fallback,香港自动,台湾自动,日本自动,新加坡自动,美国自动,url=http://www.gstatic.com/generate_204,interval=300,max-timeout=3000"
out << "🚀 节点选择 = select,自动选择,香港节点,台湾节点,日本节点,新加坡节点,美国节点,全球节点,PROXY,DIRECT"
out << "🤖 ChatGPT = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🤖 Claude = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🤖 Gemini = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📲 电报消息 = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📹 油管视频 = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🎥 奈飞视频 = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🎥 迪士尼+ = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📺 巴哈姆特 = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📺 哔哩哔哩 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "📢 谷歌FCM = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "Ⓜ️ 微软云盘 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "Ⓜ️ 微软服务 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "🍎 苹果服务 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "🎮 游戏平台 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "🎶 网易音乐 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "🛑 广告拦截 = select,REJECT,DIRECT"
out << "🍃 应用净化 = select,REJECT,DIRECT"
out << "☁️ CloudFlare = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "📹 TikTok = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📺 HBO系列 = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🎥 亚马逊视频 = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📺 Hulu = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "📹 DAZN = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🎮 Steam下载 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "🎮 Steam网页 = select,DIRECT,自动选择,🚀 节点选择,全球节点,PROXY"
out << "🤖 Copilot = select,自动选择,🚀 节点选择,全球节点,PROXY,DIRECT"
out << "🎯 全球直连 = select,DIRECT,🚀 节点选择"
out << "🐟 漏网之鱼 = select,🚀 节点选择,DIRECT"
out << ""
out << "[Rule]"
out << "FINAL,#{final_policy}"
out << ""
out << "[Remote Rule]"
remote_rules.each { |rr| out << rr }

File.write(OUTPUT_LCF, out.join("\n") + "\n")
puts "Built #{OUTPUT_LCF} with #{remote_rules.size} remote rules."
