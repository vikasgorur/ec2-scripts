#!/usr/bin/env ruby

require 'rubygems'
require 'AWS'
require 'optparse'

ACCESS_KEY_ID = ENV['ACCESS_KEY_ID']
SECRET_ACCESS_KEY = ENV['SECRET_ACCESS_KEY']

def describe(filterOwner="")
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)

  puts "Instance ID\t#{'Owner'.ljust(12)}\t#{'Name'.ljust(20)}\tLaunch Time\n\n"

  if filterOwner != ""
    rsItems = ec2.describe_instances(:filter => [{"tag:Owner" => filterOwner}]).reservationSet.item
  else
    rsItems = ec2.describe_instances().reservationSet.item
  end

  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId
      launchTime = instanceItem.launchTime.gsub(/T|Z/, " ")

      owner = ""
      name = ""

      if not instanceItem.tagSet.nil?
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Owner"}[0]
        if not tag.nil?
          owner = tag.value
        end

        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Name"}[0]
        if not tag.nil? and not tag.value.nil?
          name = tag.value
        end
      end

      puts "#{instanceId}\t#{owner.ljust(12)}\t#{name.ljust(20)}\t#{launchTime}"
    end
  end
end

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: list-instances [-o <Owner>]"

  options[:owner] = ""
  opts.on('-o', '--owner OWNER', 'Show only instances belonging to given owner') do |o|
    options[:owner] = o
  end
end

optparse.parse!

describe(filterOwner=options[:owner])

