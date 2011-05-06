def url_for_region(region)
  region_urls = {
    "eu-west-1" =>	"ec2.eu-west-1.amazonaws.com",
    "us-east-1" => "ec2.us-east-1.amazonaws.com",
    "ap-northeast-1" => "ec2.ap-northeast-1.amazonaws.com",
    "us-west-1" => "ec2.us-west-1.amazonaws.com",
    "ap-southeast-1" => "ec2.ap-southeast-1.amazonaws.com"
  }

  region_urls[region]
end


def verify_access_key()
  if not (ENV.has_key?("AMAZON_ACCESS_KEY_ID") and ENV.has_key?("AMAZON_SECRET_ACCESS_KEY"))
    puts "Please set AMAZON_ACCESS_KEY_ID and AMAZON_SECRET_ACCESS_KEY."
    exit(1)
  end
end


def gluster_ami_for_region(region)
  amis = {
    "us-east-1" => "ami-5c8d7e35",
    "us-west-1" => "ami-f3d686b6",
    "eu-west-1" => "ami-83e3d7f7",
#    "ap-northeast-1" => "",
    "ap-southeast-1" => "ami-83e3d7f7"
  }

  amis[region]
end
