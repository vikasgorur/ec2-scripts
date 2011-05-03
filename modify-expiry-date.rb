#!/usr/bin/env ruby

begin
  require 'rubygems'
  require 'AWS'
  require 'optparse'
  require 'date'
rescue LoadError
  puts "Could not load a required module. Make sure you have the gem 'amazon-ec2' installed."
  exit(1)
end

ACCESS_KEY_ID = ENV['AMAZON_ACCESS_KEY_ID']
SECRET_ACCESS_KEY = ENV['AMAZON_SECRET_ACCESS_KEY']


def modify_expiry_date(options, instance_name)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)

  result = ec2.describe_instances()

  if not result.reservationSet.nil?
    rsItems = result.reservationSet.item
  else
    return
  end

  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId

      owner = ""
      name = ""
      expire_date = nil
      new_expire_date = nil

      state = instanceItem.instanceState.name

      if not instanceItem.tagSet.nil?
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Owner"}[0]
        if not tag.nil?
          owner = tag.value
        end

        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Nickname"}[0]
        if not tag.nil? and not tag.value.nil?
          name = tag.value
        end

        expire_date = nil
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Expires"}[0]
        if not tag.nil? and not tag.value.nil?
          expire_date = DateTime.parse(tag.value)
        end
      end

      if owner == options[:owner] and name == instance_name and state == "running"
        if not options[:plus].empty?
          new_expire_date = expire_date + options[:plus].to_i
        end

        if not options[:minus].empty?
          new_expire_date = expire_date - options[:minus].to_i
        end

        ec2.create_tags(:resource_id => instanceId, :tag => [{"Expires" => new_expire_date.to_s}])
        puts "New expiration date for #{instanceId}: #{new_expire_date}."
      end
    end
  end
end


def verify_access_key()
  if not (ENV.has_key?("AMAZON_ACCESS_KEY_ID") and ENV.has_key?("AMAZON_SECRET_ACCESS_KEY"))
    puts "Please set AMAZON_ACCESS_KEY_ID and AMAZON_SECRET_ACCESS_KEY."
    exit(1)
  end
end


def main()
  options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: modify-expiry-date -o OWNER [-p N] [-m N] NAME"

    options[:plus] = ""
    opts.on('-p', '--plus N', "Add N days to the expiry date") { |n| options[:plus] = n }

    options[:minus] = ""
    opts.on('-m', '--minus N', "Subtract N days from the expiry date") { |n| options[:minus] = n }

    options[:owner] = ""
    opts.on('-o', '--owner OWNER', "Owner of the instance") { |o| options[:owner] = o }
  end

  begin
    optparse.parse!
  rescue OptionParser::InvalidOption
    puts optparse.help
    exit(1)
  end

  if (options[:plus].empty? and options[:minus].empty?) or options[:owner].empty? or ARGV.length != 1
    puts "Must specify OWNER, and NAME, and --plus or --minus."
    puts optparse.help
    exit(1)
  end

  if (not options[:plus].empty? and not options[:minus].empty?)
    puts "Cannot specify both --plus and --minus"
    puts optparse.help
    exit (1)
  end

  name = ARGV[0]

  verify_access_key()
  modify_expiry_date(options, name)
end


main()
