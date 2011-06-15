#!/usr/bin/env ruby

begin
  require 'rubygems'
  require 'date'
  require 'AWS'
  require 'optparse'
  require 'common'
rescue LoadError
  puts "Could not load a required module. Make sure you have the gem 'amazon-ec2' installed."
  exit(1)
end

ACCESS_KEY_ID = ENV['AMAZON_ACCESS_KEY_ID']
SECRET_ACCESS_KEY = ENV['AMAZON_SECRET_ACCESS_KEY']


def list_volumes(server, options)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY,
                           :server => server)

  vs = ec2.describe_volumes()

  if not vs.volumeSet.nil?
    vsItems = vs.volumeSet.item
  else
    return
  end

  puts "#{"Volume ID".ljust(14)}  #{"Status".ljust(12)}\n\n"
  vsItems.each do |item|
    if options[:all] or item.status == "available"
      puts "#{item.volumeId.ljust(14)}  #{item.status.ljust(12)}"
    end
  end
end


def main()
  options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: list-volumes [-a] [-r REGION]"

    options[:region] = "us-east-1"
    opts.on('-r', '--region REGION', "Show instances from REGION (default: us-east-1)") do |r|
      options[:region] = r
      if url_for_region(r).nil?
        puts "Region '#{r}' is not valid."
        exit(1)
      end
    end

    options[:all] = false
    opts.on('-a', '--all', "Show all volumes, not just unattached ones.") { |a| options[:all] = true }
  end

  begin
    optparse.parse!
  rescue OptionParser::InvalidOption
    puts optparse.help
    exit(1)
  end

  verify_access_key()

  server = url_for_region(options[:region])
  list_volumes(server, options)
end


main()
