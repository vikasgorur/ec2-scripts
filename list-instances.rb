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

def list_instances(server, filterOwner="", showOnlyExpired=false)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY,
                           :server => server)

  puts "#{'Instance ID'.ljust(12)}  #{'Type'.ljust(14)}  #{'Billing'.ljust(10)}  #{'DNS'.ljust(48)}  #{'Expires'.ljust(8)}  #{'Owner'.ljust(12)}  #{'Name'.ljust(20)}\n\n"

  result = ec2.describe_instances()

  if not result.reservationSet.nil?
    rsItems = result.reservationSet.item
  else
    return
  end

  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId
      dns        = instanceItem.dnsName
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

        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Nickname"}[0]
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
        puts "#{instanceId.ljust(12)}  #{type.ljust(14)}  #{billing.ljust(10)}  #{dns.ljust(48)}  #{expires.ljust(8)}  #{owner.ljust(12)}  #{name.ljust(20)}"
      end
    end
  end
end


def main()
  options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: list-instances [-o <Owner>] [-r REGION]"

    options[:region] = "us-east-1"
    opts.on('-r', '--region REGION', "Show instances from REGION (default: us-east-1)") do |r|
      options[:region] = r
      if url_for_region(r).nil?
        puts "Region '#{r}' is not valid."
        exit(1)
      end
    end

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

  verify_access_key()

  server = url_for_region(options[:region])
  list_instances(server, filterOwner=options[:owner], showOnlyExpired=options[:expired])
end


main()
