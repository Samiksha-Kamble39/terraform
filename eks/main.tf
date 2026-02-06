provider "aws" {
    region = "us-east-1"
}
resource "aws_iam_role" "cluster_role" {
    name = "eks-cluster_role1"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = aws_iam_role.cluster_role.name
}

resource "aws_iam_role" "node_group_role" {
    name = "node-group-role1"

    assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "CNI_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role = aws_iam_role.node_group_role.name
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_subnet" "az1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "eks-subnet-1"
  }
}

resource "aws_subnet" "az2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "eks-subnet-2"
  }
}

resource "aws_subnet" "az3" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "eks-subnet-3"
  }
}


resource "aws_eks_cluster" "eks_cluster" {
   name = "eks"
   version = "1.31"

   access_config {
    authentication_mode = "API"
   }

   role_arn = aws_iam_role.cluster_role.arn
   

   vpc_config {
    subnet_ids = [
      aws_subnet.az1.id,
      aws_subnet.az2.id,
      aws_subnet.az3.id,
    ]
                 
   }

   depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
   ]
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my_node_group"
  node_role_arn  = aws_iam_role.node_group_role.arn

  subnet_ids = [
    aws_subnet.az1.id,
    aws_subnet.az2.id,
    aws_subnet.az3.id,
  ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.CNI_policy,
    aws_iam_role_policy_attachment.ec2_policy
  ]
}
