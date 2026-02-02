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

resource "aws_launch_template" "prod" {
  name_prefix   = "prod-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash

    exec > /var/log/user-data.log 2>&1

    echo "Starting user-data..."

    # Update system
    apt-get update -y
    apt-get install -y curl git

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs

    # Switch to ubuntu user home
    cd /home/ubuntu

    # Clone repo (only if not exists)
    if [ ! -d "prod-dev-deployment" ]; then
      git clone https://github.com/anupsharma329/prod-dev-deployment.git
    fi

    cd prod-dev-deployment/app

    # Fix ownership BEFORE npm
    chown -R ubuntu:ubuntu /home/ubuntu/prod-dev-deployment

    # Install deps as ubuntu
    sudo -u ubuntu npm install

    # Create systemd service
    cat <<SERVICE > /etc/systemd/system/nodeapp.service
    [Unit]
    Description=Node.js prod App
    After=network.target

    [Service]
    Type=simple
    User=ubuntu
    WorkingDirectory=/home/ubuntu/prod-dev-deployment/app
    ExecStart=/usr/bin/node app.js
    Restart=always
    RestartSec=5
    Environment=NODE_ENV=production

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # Reload systemd
    systemctl daemon-reload

    # Start service
    systemctl enable nodeapp
    systemctl restart nodeapp

    # Wait for app
    sleep 10

    # Test locally
    curl http://127.0.0.1:3000/ || echo "Local health check failed"

    systemctl status nodeapp --no-pager

    echo "User-data completed."
    EOF
  )
}
resource "aws_launch_template" "dev" {
  name_prefix   = "dev-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash

    exec > /var/log/user-data.log 2>&1

    echo "Starting user-data..."

    # Update system
    apt-get update -y
    apt-get install -y curl git

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs

    # Switch to ubuntu user home
    cd /home/ubuntu

    # Clone repo (only if not exists)
    if [ ! -d "prod-dev-deployment" ]; then
      git clone https://github.com/anupsharma329/prod-dev-deployment.git
    fi

    cd prod-dev-deployment/app

    # Fix ownership BEFORE npm
    chown -R ubuntu:ubuntu /home/ubuntu/prod-dev-deployment

    # Install deps as ubuntu
    sudo -u ubuntu npm install

    # Create systemd service
    cat <<SERVICE > /etc/systemd/system/nodeapp.service
    [Unit]
    Description=Node.js dev App
    After=network.target

    [Service]
    Type=simple
    User=ubuntu
    WorkingDirectory=/home/ubuntu/prod-dev-deployment/app
    ExecStart=/usr/bin/node app.js
    Restart=always
    RestartSec=5
    Environment=NODE_ENV=production

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # Reload systemd
    systemctl daemon-reload

    # Start service
    systemctl enable nodeapp
    systemctl restart nodeapp

    # Wait for app
    sleep 10

    # Test locally
    curl http://127.0.0.1:3000/ || echo "Local health check failed"

    systemctl status nodeapp --no-pager

    echo "User-data completed."
    EOF
  )
}
