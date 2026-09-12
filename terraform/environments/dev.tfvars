project             = "solicitud"
environment         = "dev"
aws_region          = "us-east-1"
vpc_cidr            = "10.20.0.0/16"
frontend_branch     = "main"
local_development   = true
multi_az            = false
deletion_protection = false
db_instance_class   = "db.t4g.micro"
task_count          = 1
# Learner Lab: descomenta AMBOS y reemplaza ACCOUNT_ID.
existing_execution_role_arn = "arn:aws:iam::674334406872:role/LabRole"
existing_task_role_arn = "arn:aws:iam::674334406872:role/LabRole"
existing_lambda_role_arn    = "arn:aws:iam::674334406872:role/LabRole"