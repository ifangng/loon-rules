#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "fileutils"

INPUT_PATH = ARGV[0] || "config.yaml"
OUT_CONF = ARGV[1] || "config/loon-standard.conf"
OUT_RULE_DIR = ARGV[2] || "config/rules"
BASE_URL = ARGV[3] || "https://example.com/loon-rules/config/rules"

TRAILING_FLAGS = ["no-resolve"].freeze
POLICY_FILE_MAP = {
  "🎯 全球直连" => "core-direct",
  "🤖 ChatGPT" => "ai-chatgpt",
  "🤖 Claude" => "ai-claude",
  "🤖 Gemini" => "ai-gemini",
  "🤖 Copilot" => "ai-copilot",
  "📲 电报消息" => "social-telegram",
  "📹 TikTok" => "social-tiktok",
  "📺 哔哩哔哩" => "social-bilibili",
  "📹 油管视频" => "stream-youtube",
  "🎥 奈飞视频" => "stream-netflix",
  "🎥 迪士尼+" => "stream-disneyplus",
  "📺 巴哈姆特" => "stream-bahamut",
  "📺 HBO系列" => "stream-hbo",
  "🎥 亚马逊视频" => "stream-prime-video",
  "📺 Hulu" => "stream-hulu",
  "📹 DAZN" => "stream-dazn",
  "📢 谷歌FCM" => "platform-google-fcm",
  "Ⓜ️ 微软云盘" => "platform-onedrive",
  "Ⓜ️ 微软服务" => "platform-microsoft",
  "🍎 苹果服务" => "platform-apple",
  "☁️ CloudFlare" => "platform-cloudflare",
  "🎮 游戏平台" => "game-global",
  "🎮 Steam下载" => "game-steam-download",
  "🎮 Steam网页" => "game-steam-web",
  "🎶 网易音乐" => "music-netease",
  "🛑 广告拦截" => "security-ads",
  "🍃 应用净化" => "security-privacy",
  "REJECT" => "security-reject",
  "🚀 节点选择" => "routing-proxy"
}.freeze

def bool(v)
  v ? "true" : "false"
end

def text(v)
  v.to_s.strip
end

def policy_to_file_stem(policy, index)
  mapped = POLICY_FILE_MAP[policy]
  return mapped if mapped && !mapped.empty?
  "policy-#{format('%02d', index + 1)}"
end

def convert_proxy(proxy)
  name = text(proxy["name"])
  type = proxy["type"].to_s
  case type
  when "trojan"
    parts = []
    parts << "password=#{proxy['password']}" if proxy["password"]
    parts << "sni=#{proxy['sni']}" if proxy["sni"]
    parts << "skip-cert-verify=#{bool(proxy['skip-cert-verify'])}" unless proxy["skip-cert-verify"].nil?
    parts << "udp=#{bool(proxy['udp'])}" unless proxy["udp"].nil?
    parts << "tfo=#{bool(proxy['tfo'])}" unless proxy["tfo"].nil?
    "#{name} = trojan, #{proxy['server']}, #{proxy['port']}, #{parts.join(', ')}"
  else
    raise "Unsupported proxy type: #{type} (#{name})"
  end
end

def convert_group(group)
  name = text(group["name"])
  type = group["type"].to_s
  nodes = (group["proxies"] || []).map { |x| text(x) }
  case type
  when "select"
    "#{name} = select, #{nodes.join(', ')}"
  when "url-test", "fallback"
    url = group["url"] || "http://www.gstatic.com/generate_204"
    interval = group["interval"] || 300
    "#{name} = #{type}, #{nodes.join(', ')}, url=#{url}, interval=#{interval}"
  else
    raise "Unsupported proxy group type: #{type} (#{name})"
  end
end

def split_rule(rule)
  parts = rule.to_s.split(",").map(&:strip)
  return nil if parts.empty?

  if parts[0] == "MATCH"
    return { final_policy: text(parts[1] || "DIRECT") }
  end

  policy_index = parts.length - 1
  if parts.length >= 4 && TRAILING_FLAGS.include?(parts[-1].downcase)
    policy_index = parts.length - 2
  end

  policy = text(parts[policy_index])
  entry = parts.dup
  entry.delete_at(policy_index)
  { policy: policy, entry: entry.join(",") }
end

raw = YAML.load_file(INPUT_PATH)
proxies = raw["proxies"] || []
groups = raw["proxy-groups"] || []
rules = raw["rules"] || []

policy_to_rules = {}
policy_order = []
final_policy = "DIRECT"

rules.each do |rule|
  parsed = split_rule(rule)
  next unless parsed

  if parsed[:final_policy]
    final_policy = parsed[:final_policy]
    next
  end

  policy = parsed[:policy]
  policy_order << policy unless policy_to_rules.key?(policy)
  policy_to_rules[policy] ||= []
  policy_to_rules[policy] << parsed[:entry]
end

FileUtils.mkdir_p(OUT_RULE_DIR)
Dir.glob(File.join(OUT_RULE_DIR, "*.list")).each { |path| File.delete(path) }
manifest = []
used_file_names = {}

policy_order.each_with_index do |policy, idx|
  stem = policy_to_file_stem(policy, idx)
  file_name = "#{stem}.list"
  if used_file_names[file_name]
    suffix = used_file_names[file_name] + 1
    used_file_names[file_name] = suffix
    file_name = "#{stem}-#{suffix}.list"
  else
    used_file_names[file_name] = 1
  end
  path = File.join(OUT_RULE_DIR, file_name)
  File.write(path, policy_to_rules[policy].join("\n") + "\n")
  manifest << [policy, file_name, policy_to_rules[policy].size]
end

out = []
out << "[General]"
out << "bypass-system = true"
out << "skip-proxy = 192.168.0.0/16, 10.0.0.0/8, 127.0.0.1, localhost, *.local"
out << ""
out << "[Proxy]"
proxies.each { |p| out << convert_proxy(p) }
out << ""
out << "[Proxy Group]"
groups.each { |g| out << convert_group(g) }
out << ""
out << "[Rule]"
manifest.each do |policy, file_name, _count|
  out << "RULE-SET,#{BASE_URL}/#{file_name},#{policy}"
end
out << "FINAL,#{final_policy}"
out << ""
out << "# Manifest (policy -> file)"
manifest.each do |policy, file_name, count|
  out << "# #{file_name} <= #{policy} (#{count} rules)"
end

File.write(OUT_CONF, out.join("\n") + "\n")

puts "Built Loon standard package:"
puts "- config: #{OUT_CONF}"
puts "- rules dir: #{OUT_RULE_DIR}"
puts "- base url: #{BASE_URL}"
puts "- rulesets: #{manifest.size}"
puts "- final policy: #{final_policy}"
