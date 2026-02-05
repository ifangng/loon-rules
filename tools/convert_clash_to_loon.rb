#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

INPUT_PATH = ARGV[0] || "config.yaml"
OUTPUT_PATH = ARGV[1] || "config/loon.conf"

def bool(v)
  v ? "true" : "false"
end

def normalize_name(value)
  value.to_s.strip
end

def convert_proxy(proxy)
  name = normalize_name(proxy["name"])
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
    raise "Unsupported proxy type: #{type} (proxy: #{name})"
  end
end

def convert_group(group)
  name = normalize_name(group["name"])
  type = group["type"].to_s
  nodes = (group["proxies"] || []).map { |x| normalize_name(x) }

  case type
  when "select"
    "#{name} = select, #{nodes.join(', ')}"
  when "url-test"
    url = group["url"] || "http://www.gstatic.com/generate_204"
    interval = group["interval"] || 300
    "#{name} = url-test, #{nodes.join(', ')}, url=#{url}, interval=#{interval}"
  when "fallback"
    url = group["url"] || "http://www.gstatic.com/generate_204"
    interval = group["interval"] || 300
    "#{name} = fallback, #{nodes.join(', ')}, url=#{url}, interval=#{interval}"
  else
    raise "Unsupported group type: #{type} (group: #{name})"
  end
end

def normalize_rule(rule)
  parts = rule.to_s.split(",").map(&:strip)
  return rule.to_s if parts.empty?

  parts[0] = "FINAL" if parts[0] == "MATCH"
  parts.join(",")
end

raw = YAML.load_file(INPUT_PATH)

proxies = raw["proxies"] || []
groups = raw["proxy-groups"] || []
rules = raw["rules"] || []

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
rules.each { |r| out << normalize_rule(r) }

File.write(OUTPUT_PATH, out.join("\n") + "\n")

puts "Converted:"
puts "- input: #{INPUT_PATH}"
puts "- output: #{OUTPUT_PATH}"
puts "- proxies: #{proxies.size}"
puts "- groups: #{groups.size}"
puts "- rules: #{rules.size}"
