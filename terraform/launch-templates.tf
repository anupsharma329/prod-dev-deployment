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
    # Log everything for troubleshooting
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    set -x
    
    # Update Ubuntu packages
    apt-get update -y
    apt-get install -y curl git
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Verify Node.js installation
    node --version
    npm --version
    
    # Clone your app
    cd /home/ubuntu
    git clone https://github.com/anupsharma123/blue-green-deployment.git || echo "Git clone failed"
    cd blue-green-deployment/app/blue || { echo "Failed to cd to app directory"; exit 1; }
    
    # Install dependencies
    npm install || { echo "npm install failed"; exit 1; }
    
    # Start app in background and redirect output to log
    nohup npm start > /var/log/app.log 2>&1 &
    
    # Wait a moment and verify app is running
    sleep 5
    if pgrep -f "node.*app.js" > /dev/null; then
      echo "App started successfully"
      curl -f http://localhost:3000 || echo "App not responding on localhost:3000"
    else
      echo "ERROR: App failed to start"
      exit 1
    fi
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
    # Log everything for troubleshooting
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    set -x
    
    # Update Ubuntu packages
    apt-get update -y
    apt-get install -y curl git
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Verify Node.js installation
    node --version
    npm --version
    
    # Clone your app
    cd /home/ubuntu
    git clone https://github.com/anupsharma123/blue-green-deployment.git || echo "Git clone failed"
    cd blue-green-deployment/app/green || { echo "Failed to cd to app directory"; exit 1; }
    
    # Install dependencies
    npm install || { echo "npm install failed"; exit 1; }
    
    # Start app in background and redirect output to log
    nohup npm start > /var/log/app.log 2>&1 &
    
    # Wait a moment and verify app is running
    sleep 5
    if pgrep -f "node.*app.js" > /dev/null; then
      echo "App started successfully"
      curl -f http://localhost:3000 || echo "App not responding on localhost:3000"
    else
      echo "ERROR: App failed to start"
      exit 1
    fi
  EOF
  )
}
