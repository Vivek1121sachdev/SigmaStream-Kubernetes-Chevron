terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  # profile = "sigmastream"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "sigmastream-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = var.private_subnet_cidrs
  public_subnets  = concat(var.public_subnet_cidrs)

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true

  tags = {
    "Terraform"   = "true"
    "Environment" = "prod"
  }
}

# Allow EKS nodes to access DBs
resource "aws_security_group" "eks_nodes" {
  name_prefix = "eks-nodes-"
  vpc_id      = module.vpc.vpc_id

  egress {
    description      = "All outbound"
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "eks-nodes-sg"
    Environment = "prod"
  }
}

resource "aws_security_group" "aurora_postgresql" {
  name_prefix = "aurora-postgresql-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow from VPC"
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description      = "All outbound"
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "aurora-postgresql-sg"
    Environment = "prod"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "idempiere-prod-cluster"
  cluster_version = "1.29"

  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  enable_cluster_creator_admin_permissions = true

  

  eks_managed_node_groups = {
    app = {
      instance_types = ["c6i.2xlarge"]
      min_size       = 1
      max_size       = 5
      desired_size   = 1
      taints = [{
        key    = "app"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    },
    mongo = {
      instance_types = ["c6i.2xlarge"]

      iam_role_additional_policies = {
        ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      min_size       = 1
      max_size       = 1
      desired_size   = 1
      taints = [{
        key    = "mongodb"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}


resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "ClusterAutoscalerPolicy"
  description = "Policy for EKS Cluster Autoscaler"
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ]
    resources = ["*"]
  }
}

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "cluster-autoscaler-irsa"

  attach_cluster_autoscaler_policy = true

  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}



module "aurora_postgresql_serverless_v2" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"

  name           = "aurora-pg-serverless"
  engine         = "aurora-postgresql"
  engine_version = "15.10"

  master_username = "auroraadmin"
  master_password = var.aurora_password

  instance_class = "db.serverless"

  instances = {
    writer = {
      instance_class = "db.serverless"
      publicly_accessible = false
    },
    reader1 = {
      instance_class = "db.serverless"
      publicly_accessible = false
    }
  }

  serverlessv2_scaling_configuration = {
    min_capacity = 8
    max_capacity = 256
  }

  vpc_id                = module.vpc.vpc_id
  create_db_subnet_group = true
  vpc_security_group_ids = [aws_security_group.aurora_postgresql.id]
  subnets               = module.vpc.private_subnets

  storage_encrypted     = true
  manage_master_user_password = false
  publicly_accessible   = false
  apply_immediately     = true
  enable_http_endpoint  = true
  monitoring_interval   = 0

  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  preferred_maintenance_window = "sun:03:00-sun:04:00"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  skip_final_snapshot = true

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}


resource "aws_route53_zone" "private_db" {
  name = "mydb.internal"
  vpc {
    vpc_id = module.vpc.vpc_id
  }
  comment = "Private hosted zone for Aurora writer endpoint"
}

resource "aws_route53_record" "db_writer_cname" {
  zone_id = aws_route53_zone.private_db.zone_id
  name    = "db.mydb.internal"
  type    = "CNAME"
  ttl     = 300
  records = [module.aurora_postgresql_serverless_v2.cluster_endpoint]
}   