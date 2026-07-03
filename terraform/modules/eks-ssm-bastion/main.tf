# SSM-managed bastion for reaching a PRIVATE EKS API endpoint (CZID #322).
#
# No SSH, no public IP, no inbound: operators connect via SSM Session Manager
#   aws ssm start-session --target <bastion_instance_id>
# and run kubectl against the private control-plane endpoint. The bastion lives
# in a private subnet whose NAT egress reaches the SSM + EKS endpoints on 443.
#
# This MUST be deployed together with the endpoint_public_access = false flip, or
# the control plane becomes unreachable (operator lockout). The consuming eks
# stack gates both on the same var.eks_endpoint_private toggle.
#
# NOTE: this is the CONTROL PLANE access path only. It does NOT touch the app
# data path — the internet-facing app ALB (AWS LB Controller, #321) is unrelated
# and stays reachable. Making the API private does not affect end-user ingress.

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# --- IAM: an SSM-managed instance (AmazonSSMManagedInstanceCore = SSM agent perms) ---
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name_prefix        = "${var.name}-eks-bastion-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.name}-eks-bastion-"
  role        = aws_iam_role.bastion.name
  tags        = var.tags
}

# --- Network: egress-only bastion SG + allow it to reach the cluster API on 443 ---
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name}-eks-bastion-"
  description = "SSM bastion for private EKS API access (egress-only)"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.bastion.id
  description       = "HTTPS egress (SSM endpoints + EKS API)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow the bastion to reach the EKS control-plane API (443) on the cluster SG.
resource "aws_vpc_security_group_ingress_rule" "cluster_from_bastion" {
  security_group_id            = var.cluster_security_group_id
  description                  = "EKS API from the SSM bastion (CZID #322)"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.bastion.id
}

# --- The instance (private, IMDSv2, encrypted root, monitored) ---
resource "aws_instance" "bastion" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = false
  monitoring                  = true # CKV_AWS_126
  ebs_optimized               = true # CKV_AWS_135

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 (CKV_AWS_79)
  }

  root_block_device {
    encrypted   = true # CKV_AWS_8
    volume_size = 8
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "${var.name}-eks-ssm-bastion" })
}
