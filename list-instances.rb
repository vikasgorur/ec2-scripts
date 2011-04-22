#!/usr/bin/env ruby

require 'rubygems'
require 'AWS'
require 'optparse'

ACCESS_KEY_ID = ENV['AMAZON_ACCESS_KEY_ID']
SECRET_ACCESS_KEY = ENV['AMAZON_SECRET_ACCESS_KEY']

def describe(filterOwner="", showOnlyExpired=false)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)

  puts "#{'Instance ID'.ljust(12)}  #{'Type'.ljust(14)}  #{'Billing'.ljust(10)}  #{'Launch Time'.ljust(24)}  #{'Expires'.ljust(8)}  #{'Owner'.ljust(12)}  #{'Name'.ljust(20)}\n\n"

  rsItems = ec2.describe_instances().reservationSet.item

  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId
      launchTime = instanceItem.launchTime.gsub(/T|Z/, " ")
      type       = instanceItem.instanceType
      if instanceItem.instanceLifecycle.nil?
        billing = "On-demand"
      else
        billing = "Spot"
      end

      state = instanceItem.instanceState.name

      owner = ""
      name = ""
      expires = ""

      if not instanceItem.tagSet.nil?
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Owner"}[0]
        if not tag.nil?
          owner = tag.value
        end

        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Name"}[0]
        if not tag.nil? and not tag.value.nil?
          name = tag.value
        end

        expire_date = nil
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Expires"}[0]
        if not tag.nil? and not tag.value.nil?
          expire_date = DateTime.parse(tag.value)
          expires = "#{(DateTime.parse(tag.value) - DateTime.now).to_i} days"
        end
      end

      if ((filterOwner.empty?) or (filterOwner == owner)) and (state == "running") and
          ((showOnlyExpired == false) or (not expire_date.nil? and (expire_date < DateTime.now)))
        puts "#{instanceId.ljust(12)}  #{type.ljust(14)}  #{billing.ljust(10)}  #{launchTime.ljust(24)}  #{expires.ljust(8)}  #{owner.ljust(12)}  #{name.ljust(20)}"
      end
    end
  end
end

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: list-instances [-o <Owner>]"

  options[:owner] = ""
  opts.on('-o', '--owner OWNER', "Show only instances belonging to given owner") { |o| options[:owner] = o }

  options[:expired] = false
  opts.on('-e', '--expired', "Show only expired instances") { |e| options[:expired] = true }
end

begin
  optparse.parse!
rescue OptionParser::InvalidOption
  puts optparse.help
  exit(1)
end

describe(filterOwner=options[:owner], showOnlyExpired=options[:expired])

