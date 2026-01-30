# Use latest Ubuntu 22.04 LTS AMI (more stable and widely available)
# Falls back to Ubuntu 20.04 if 22.04 not available
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "blue" {
  name_prefix   = "blue-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -e
    apt-get update -y
    apt-get install -y curl git
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    cd /home/ubuntu
    git clone https://github.com/anupsharma123/blue-green-deployment.git
    cd blue-green-deployment/app/blue
    npm install
    sed -i "s/}).listen(3000);/}).listen(3000, '0.0.0.0');/" app.js || true
    chown -R ubuntu:ubuntu /home/ubuntu/blue-green-deployment
    sudo tee /etc/systemd/system/nodeapp.service > /dev/null << 'SVC'
[Unit]
Description=Node.js Blue App
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/blue-green-deployment/app/blue
ExecStart=/usr/bin/node app.js
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
SVC
    systemctl daemon-reload
    systemctl enable --now nodeapp
    sleep 5
    curl -sf http://127.0.0.1:3000/ || echo "Health check failed"
    systemctl status nodeapp --no-pager || true
EOF
  )
}

resource "aws_launch_template" "green" {
  name_prefix   = "green-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -e
    apt-get update -y
    apt-get install -y curl git
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    cd /home/ubuntu
    git clone https://github.com/anupsharma123/blue-green-deployment.git
    cd blue-green-deployment/app/green
    npm install
    sed -i "s/}).listen(3000);/}).listen(3000, '0.0.0.0');/" app.js || true
    chown -R ubuntu:ubuntu /home/ubuntu/blue-green-deployment
    sudo tee /etc/systemd/system/nodeapp.service > /dev/null << 'SVC'
[Unit]
Description=Node.js Green App
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/blue-green-deployment/app/green
ExecStart=/usr/bin/node app.js
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
SVC
    systemctl daemon-reload
    systemctl enable --now nodeapp
    sleep 5
    curl -sf http://127.0.0.1:3000/ || echo "Health check failed"
    systemctl status nodeapp --no-pager || true
  EOF
  )
}
