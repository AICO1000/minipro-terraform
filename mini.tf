# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
  profile = "default"
}

# Create a security group
resource "aws_security_group" "instance" {
  name_prefix = "mini-project"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Elastic Load Balancer
resource "aws_elb" "load" {
  name               = "mini-project-elb"
  security_groups    = [aws_security_group.instance.id]
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# Create the EC2 instances
resource "aws_instance" "example" {
  count             = 3
  ami               = "ami-0c94855ba95c71c99"
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.instance.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > index.html
              sudo mv index.html /var/www/html/index.html
              sudo timedatectl set-timezone Africa/Lagos
              sudo systemctl restart httpd
              EOF
  tags = {
    Name = "terraform-example-instance-${count.index + 1}"
  }
}

# Register the EC2 instances with the Elastic Load Balancer
resource "aws_elb_attachment" "project" {
  count       = 3
  elb_id      = aws_elb.project.id
  instance_id = aws_instance.project[count.index].id
}

# Export the public IP addresses to a file
data "template_file" "host_inventory" {
  count = 3
  template = <<EOF
    ${element(aws_instance.project.*.public_ip, count.index)}
  EOF
}

output "host_inventory" {
  value = data.template_file.host_inventory.*.rendered
}

# Create the Route53 DNS record
resource "aws_route53_zone" "routep" {
  name = "aicodeen.me"
}

resource "aws_route53_record" "record" {
  zone_id = aws_route53_zone.routep.zone_id
  name    = "terraform-test.aicodeen.me"
  type    = "A"
  alias {
    name                   = aws_elb.load.dns_name
    zone_id                = aws_elb.routep.zone_id
    evaluate_target_health = true
  }
}
