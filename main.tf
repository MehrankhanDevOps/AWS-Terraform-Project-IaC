resource "aws_vpc" "terraform_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terraform_vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "Pulic1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "Pulic2"
  }
}

resource "aws_instance" "EC21" {
  ami             = "ami-005fc0f236362e99f"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public1.id
  security_groups = [aws_security_group.SG_EC2.id]
  user_data       = file("${path.module}/userdata1.sh")
  tags = {
    "Name" = "EC21"
  }
}


resource "aws_instance" "EC22" {
  ami             = "ami-005fc0f236362e99f"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.SG_EC2.id]
  subnet_id       = aws_subnet.public2.id
  user_data       = file("${path.module}/userdatda2.sh")
  tags = {
    "Name" = "EC22"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.terraform_vpc.id
  tags = {
    "Name" = "TF_GW"
  }
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "TF_RT"
  }
}

resource "aws_route_table_association" "RTA1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.RT.id
}
resource "aws_route_table_association" "RTA2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_lb" "TF_LB" {
  name               = "TFLB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG_LB.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  tags = {
    Name = "TF_LB"
  }
}

resource "aws_lb_target_group" "TF_TG" {
  name     = "TFTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform_vpc.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group_attachment" "TF_TGA1" {
  target_group_arn = aws_lb_target_group.TF_TG.arn
  target_id        = aws_instance.EC21.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "TF_TGA2" {
  target_group_arn = aws_lb_target_group.TF_TG.arn
  target_id        = aws_instance.EC22.id
  port             = 80
}

resource "aws_lb_listener" "TF_LB_Listener" {
  load_balancer_arn = aws_lb.TF_LB.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TF_TG.arn
  }
}



resource "aws_security_group" "SG_LB" {
  name   = "SG_LB"
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "SG_LB"
  }
}

resource "aws_vpc_security_group_ingress_rule" "SG_ingress_LB" {
  security_group_id = aws_security_group.SG_LB.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "SG_egress_LB" {
  security_group_id = aws_security_group.SG_LB.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}



resource "aws_security_group" "SG_EC2" {
  name   = "SG_EC2"
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "SG_LB"
  }
}

resource "aws_vpc_security_group_ingress_rule" "SG_ingress_EC2" {
  security_group_id = aws_security_group.SG_EC2.id
  referenced_security_group_id = aws_security_group.SG_LB.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "SG_ingress_EC2" {
  security_group_id = aws_security_group.SG_EC2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
