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


def create_spot_instance(server, name, options)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY,
                           :server => server)

  if not options[:ami].empty?
    ami = options[:ami]
  else
    ami = gluster_ami_for_region(options[:region])
    if ami.nil?
      puts "No Gluster AMI known for region #{options[:region]}."
      exit(1)
    end
  end

  reqStarted = Time.now
  req = ec2.request_spot_instances(:instance_count => 1, :spot_price => "0.6", :image_id => ami,
                                   :instance_type => options[:type], :availability_zone => options[:zone],
                                   :security_group => options[:group], :key_name => options[:key])

  sir = req.spotInstanceRequestSet.item[0].spotInstanceRequestId
  state = req.spotInstanceRequestSet.item[0].state

  if state == "open" or state == "active"
    puts "Spot Instance request #{sir} is now #{state}."
  else
    puts "Error. Spot Instance request #{sir} is in state '#{state}'."
  end

  STDOUT.sync = true

  print "Waiting for instances to come up"
  instanceSpawned = false
  while not instanceSpawned
    res = ec2.describe_spot_instance_requests(:spot_instance_request_id => sir)
    instanceId = res.spotInstanceRequestSet.item[0].instanceId
    price = res.spotInstanceRequestSet.item[0].spotPrice

    if instanceId.nil?
      print "."
      sleep(5)
    else
      now = Time.now
      min = ((now - reqStarted) / 60).floor
      sec = ((now - reqStarted) - min*60).floor
      puts "done (#{min}m #{sec}s)."
      puts "Instance #{instanceId} has been created."
      instanceSpawned = true
    end
  end

  tags = [{"Owner" => options[:owner]}, {"Nickname" => name}]
  if not options[:expires].empty?
    expire_date = DateTime.now + Integer(options[:expires])
    tags += [{"Expires" => expire_date.to_s}]
  end

  if not options[:mail].empty?
    tags += [{"Mail" => options[:mail]}]
  end

  ec2.create_tags(:resource_id => instanceId, :tag => tags)
end


def main()
  options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: create-spot-instance -k KEY -o OWNER [-t TYPE] [-r REGION] [-a AMI] [-z ZONE] [-g GROUP] [-e DAYS] [-m ADDR] NAME"

    options[:key] = ""
    opts.on('-k', '--key KEY', "SSH key name for the instance") { |k| options[:key] = k }

    options[:owner] = ""
    opts.on('-o', '--owner OWNER', "Owner of the instance") { |o| options[:owner] = o }

    options[:type] = "m1.large"
    opts.on('-t', '--type TYPE', "Type of the instance (default: m1.large)") { |t| options[:type] = t }

    options[:zone] = nil
    opts.on('-z', '--zone ZONE', "Availability zone for the instance") { |z| options[:zone] = z }

    options[:region] = "us-east-1"
    opts.on('-r', '--region REGION', "Region for the instance (default: us-east-1).") do |r|
      options[:region] = r
      if url_for_region(r).nil?
        puts "Region '#{r}' is not valid."
        exit(1)
      end
    end

    options[:ami] = ""
    opts.on('-a', '--ami AMI', "AMI to use for the instance (default: Gluster AMI for the region).") do |a|
      options[:ami] = a
    end

    options[:group] = "default"
    opts.on('-g', '--group GROUP', "Security group (default: 'default')") { |g| options[:group] = g }

    options[:expires] = ""
    opts.on('-e', '--expires DAYS', "Expiration period for the instance (in days)") { |e| options[:expires] = e }

    options[:mail] = ""
    opts.on('-m', '--mail ADDRESS', "E-mail address for reminders") { |m| options[:mail] = m }
  end

  begin
    optparse.parse!
  rescue OptionParser::InvalidOption
    puts optparse.help
    exit(1)
  end

  if options[:key].empty? or options[:owner].empty? or ARGV.length != 1
    puts "Must specify KEY, OWNER, and NAME"
    puts optparse.help
    exit(1)
  end

  name = ARGV[0]

  verify_access_key()

  server = url_for_region(options[:region])
  create_spot_instance(server, name, options)
end


main()
