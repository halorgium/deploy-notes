#!/usr/bin/env ruby

require 'rubygems'
require 'pathname'
require 'time'
require 'pp'

class Commit
  def initialize(sha1)
    @sha1 = sha1
  end

  def add_deploy(url, timestamp, user)
    return if deploy?(url)

    puts "adding #{url}, #{timestamp}, #{user} to #{@sha1}"

    dir = Pathname.new(`gmktemp -d`.chomp)
    note_file = dir.join("note")

    File.open(note_file, "w") do |f|
      f.puts "Deploy-Url: #{url}"
      f.puts "Deployed-At: #{timestamp}"
      f.puts "Deployed-By: #{user}"
    end

    unless system("#{deploys_prefix} append -F #{note_file} #{@sha1}")
      raise "Could not save deploy #{url} for #{@sha1}"
    end
  end

  def deploy?(url)
    deploy_urls.include?(url)
  end

  def deploy_urls
    deploys.map do |d|
      d.url
    end
  end

  def deploys?
    system("#{deploys_cmd} 2>/dev/null >/dev/null")
  end

  def deploys
    if deploys?
      output = `#{deploys_cmd}`.chomp
      output.split("\n\n").map do |lines|
        Deploy.parse(self, lines)
      end
    else
      []
    end
  end

  def deploys_cmd
    "#{deploys_prefix} show #{@sha1}"
  end

  def deploys_prefix
    "git notes --ref deploys"
  end

  def system(*args)
    pp args
    super
  end
end


class Deploy
  def self.parse(commit, lines)
    url = nil
    timestamp = nil
    user = nil
    lines.each do |line|
      case line
      when /^Deploy-Url: (.*)$/
        url = $1
      when /^Deployed-At: (.*)$/
        timestamp = $1
      when /^Deployed-By: (.*)$/
        user = $1
      else
        raise "Unknown line: #{line.inspect}"
      end
    end
    new(commit, url, timestamp, user)
  end

  def initialize(commit, url, timestamp, user)
    @commit    = commit
    @url        = url
    @timestamp = timestamp
    @user      = user
  end
  attr_reader :commit, :url, :timestamp, :user

  def time
    Time.parse(@timestamp)
  end
end
