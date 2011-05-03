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
GLUSTER_AMI="ami-5c8d7e35"

def terminate_instance(name, options)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)

  rsItems = ec2.describe_instances().reservationSet.item

  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId
      instanceOwner = ""
      instanceName = ""

      if not instanceItem.tagSet.nil?
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Owner"}[0]
        if not tag.nil?
          instanceOwner = tag.value
        end

        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Nickname"}[0]
        if not tag.nil? and not tag.value.nil?
          instanceName = tag.value
        end
      end

      if (instanceOwner == options[:owner]) and (instanceName == name)
        ec2.terminate_instances(:instance_id => instanceId)
        puts "Instance #{instanceId} terminated."
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
    opts.banner = "Usage: terminate-instance -o OWNER NAME"

    options[:owner] = ""
    opts.on('-o', '--owner OWNER', "Owner of the instance") { |o| options[:owner] = o }
  end

  optparse.parse!

  if options[:owner].empty? or ARGV.length != 1
    puts "Must specify OWNER and NAME"
    puts optparse.help
    exit(1)
  end

  name = ARGV[0]

  verify_access_key()

  terminate_instance(name, options)
end


main()
