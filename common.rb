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
    "us-east-1" => "ami-08f80661",
    "us-west-1" => "ami-23d48766",
    "eu-west-1" => "ami-7f1f290b",
#    "ap-northeast-1" => "",
    "ap-southeast-1" => "ami-e49238e5"
  }

  amis[region]
end
