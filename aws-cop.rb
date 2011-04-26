#!/usr/bin/env ruby

require 'rubygems'
require 'AWS'
require 'optparse'
require 'pony'
require 'date'
require 'pp'

ACCESS_KEY_ID = ENV['AMAZON_ACCESS_KEY_ID']
SECRET_ACCESS_KEY = ENV['AMAZON_SECRET_ACCESS_KEY']

def reap_ebs_volumes(options)
  begin
    ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)
  rescue AWS::ArgumentError
    puts "Error connecting to AWS. Make sure that AMAZON_ACCESS_KEY_ID and AMAZON_SECRET_ACCESS_KEY are set to correct values"
    exit(1)
  end

  volSet = ec2.describe_volumes().volumeSet

  volSet.item.each do |vol|
    if vol.status == "available"
      (hours, minutes, seconds, frac) = Date.day_fraction_to_time(DateTime.now - DateTime.parse(vol.createTime))

      if options[:list]
        puts "Delete volume #{vol.volumeId}."
      else
        if hours >= 1
          begin
            if not options[:dryrun]
              ec2.delete_volume(:volume_id => vol.volumeId)
            end
          rescue AWS::ArgumentError
            puts "Error deleting volume #{vol.volumeId}."
            next
          end
          puts "Deleted volume #{vol.volumeId}."
        end
      end
    end
  end
end


$reminder_text = "This is a reminder that the following instances owned by you will expire in less than 24 hours. The instances will be TERMINATED anytime after they expire. If you need an extension on these instances, please contact IT."

$termination_text = "The following instances owned by you have been TERMINATED after they expired. You should have received a reminder 24 hours ago. To avoid forceful terminations in the future, please get an extension from IT as soon as you receive the reminder."


def send_email(owners, options, type)
  owners.each do |owner, value|
    details = ""
    value.each do |inst|
      details += "#{inst[:instance].ljust(12)}    #{inst[:dns].ljust(42)}    #{inst[:expires].ljust(16)} (Pacific)\n"
    end

    if type == :termination
      body_text = $termination_text
    elsif type == :reminder
      body_text = $reminder_text
    else
      puts "Invalid value for type: '#{type.to_s}'."
      return
    end

    body = <<EOF
#{body_text}

#{'Instance ID'.ljust(12)}    #{'DNS name'.ljust(42)}    #{'Expiration timestamp'.ljust(16)}

#{details}
- Your friendly AWS cop.

This is an automatically generated messgae. Please do not reply to this.
EOF
    if options[:dryrun]
      puts "\n== To: #{owner} ==\n\n"
      puts body
      puts "\n== End of message ==\n"
    else
      if type == :termination
        subject = "Your EC2 instances have been terminated"
      elsif type == :reminder
        subject = "Your EC2 instances are about to expire!"
      else
        puts "Unknown type '#{type.to_s}'"
        return
      end

      Pony.mail(:to => owner, :from => "aws-cop@gluster.com", :subject => subject,
                :body => body, :via => :smtp, :via_options => {
                  :address                => 'saturn.datasyncintra.net',
                  :port                   => '587',
                  :enable_starttls_auto   => true,
                  :user_name              => "aws-cop@gluster.com",
                  :password               => "awsc0p",
                  :authentication         => :plain,
                  :domain                 => "localhost.localdomain"
                })
      puts "Sent #{type.to_s} email to #{owner} about #{value.length} instances."
    end
  end
end

def send_24h_reminder(options)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)

  owners = {}
  rsItems = ec2.describe_instances().reservationSet.item
  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId
      dns = instanceItem.dnsName

      email = ""
      if not instanceItem.tagSet.nil?
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Mail"}[0]
        if not tag.nil?
          email = tag.value
        end

        expire_date = nil
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Expires"}[0]
        if not tag.nil? and not tag.value.nil?
          expire_date = DateTime.parse(tag.value)
          (hours, min, secs, frac) = Date.day_fraction_to_time(expire_date - DateTime.now)
          if (hours > 0) and (hours < 24)
            if owners.has_key?(email)
              owners[email] += [{:instance => instanceId, :dns => dns, :expires => expire_date.to_s}]
            else
              owners[email] = [{:instance => instanceId, :dns => dns, :expires => expire_date.to_s}]
            end
          end
        end
      end
    end
  end

  send_email(owners, options, :reminder)
end


def terminate_expired_instances(options)
  ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)

  owners = {}
  rsItems = ec2.describe_instances().reservationSet.item
  rsItems.each do |reservationItem|
    reservationItem.instancesSet.item.each do |instanceItem|
      instanceId = instanceItem.instanceId
      dns = instanceItem.dnsName

      email = ""
      if not instanceItem.tagSet.nil?
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Mail"}[0]
        if not tag.nil?
          email = tag.value
        end

        expire_date = nil
        tag = instanceItem.tagSet.item.find_all {|i| i.key == "Expires"}[0]
        if not tag.nil? and not tag.value.nil?
          expire_date = DateTime.parse(tag.value)
          (hours, min, secs, frac) = Date.day_fraction_to_time(expire_date - DateTime.now)

          if (hours < 0) or (min < 0) or (secs < 0)
            if owners.has_key?(email)
              owners[email] += [{:instance => instanceId, :dns => dns, :expires => expire_date.to_s}]
            else
              owners[email] = [{:instance => instanceId, :dns => dns, :expires => expire_date.to_s}]
            end
          end
        end
      end
    end
  end

  pp(owners)
  owners.each do |key, value|
    value.each do |i|
      ec2.terminate_instances(:instance_id => i[:instance])
    end
  end

  send_email(owners, options, :termination)
end


options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: aws-cop [-d]"

  options[:owner] = ""
  opts.on('-d', '--dry-run', "Dry-run. Don't actually delete volumes or terminate instances") { |l| options[:dryrun] = true }
end

begin
  optparse.parse!
rescue OptionParser::InvalidOption
  puts optparse.help
  exit(1)
end

reap_ebs_volumes(options)

send_24h_reminder(options)

terminate_expired_instances(options)
