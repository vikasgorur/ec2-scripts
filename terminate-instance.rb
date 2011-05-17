#!/usr/bin/env ruby

begin
  require 'rubygems'
  require 'AWS'
  require 'optparse'
  require 'date'
  require 'common'
rescue LoadError
  puts "Could not load a required module. Make sure you have the gem 'amazon-ec2' installed."
  exit(1)
end

ACCESS_KEY_ID = ENV['AMAZON_ACCESS_KEY_ID']
SECRET_ACCESS_KEY = ENV['AMAZON_SECRET_ACCESS_KEY']
GLUSTER_AMI="ami-5c8d7e35"

def terminate_instance(server, name, options)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY,
                           :server => server)

  rsSet = ec2.describe_instances().reservationSet
  if rsSet.nil?
    puts "No instance owned by '#{options[:owner]}' named '#{name}' exists."
    return
  end

  rsItems = rsSet.item

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
        return
      end
    end
  end

  puts "No instance owned by '#{options[:owner]}' named '#{name}' exists."
end


def main()
  options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: terminate-instance -o OWNER NAME"

    options[:owner] = ""
    opts.on('-o', '--owner OWNER', "Owner of the instance") { |o| options[:owner] = o }

    options[:region] = "us-east-1"
    opts.on('-r', '--region REGION', "Region for the instance (default: us-east-1).") do |r|
      options[:region] = r
      if url_for_region(r).nil?
        puts "Region '#{r}' is not valid."
        exit(1)
      end
    end

  end

  optparse.parse!

  if options[:owner].empty? or ARGV.length != 1
    puts "Must specify OWNER and NAME"
    puts optparse.help
    exit(1)
  end

  name = ARGV[0]

  verify_access_key()

  server = url_for_region(options[:region])
  terminate_instance(server, name, options)
end


main()
