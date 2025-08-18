# RideShare Infrastructure

This directory contains the Terraform configuration for deploying the RideShare application infrastructure on AWS.

## Architecture Overview

The infrastructure consists of:

- **VPC with Public/Private Subnets**: Multi-AZ setup with NAT gateways for private subnet internet access
- **ECS Fargate Cluster**: Containerized application deployment with auto-scaling
- **Application Load Balancer**: HTTP/HTTPS traffic distribution
- **MongoDB Atlas**: Managed MongoDB cluster for data persistence
- **CloudWatch**: Logging, monitoring, and alerting
- **Security Groups**: Network-level security controls
- **IAM Roles**: Least-privilege access for ECS tasks

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **MongoDB Atlas** account and project
4. **Mapbox** account for mapping services

## Quick Start

### 1. Configure Variables

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

- MongoDB Atlas API keys and project ID
- JWT secret for authentication
- Mapbox access token
- AWS region preferences

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan
```

Review the planned changes to ensure they match your expectations.

### 4. Apply the Infrastructure

```bash
terraform apply
```

Confirm the deployment when prompted.

### 5. Access Your Application

After successful deployment, you'll get the ALB DNS name in the outputs. Your application will be available at:

```
http://<alb_dns_name>
```

## Infrastructure Components

### VPC Module (`./modules/vpc`)

- Creates a VPC with public and private subnets across multiple AZs
- Sets up NAT gateways for private subnet internet access
- Configures route tables for proper traffic routing

### ECS Module (`./modules/ecs`)

- ECS Fargate cluster for containerized deployment
- Task definition with environment variables
- Service with load balancer integration
- IAM roles for task execution and permissions

### ALB Module (`./modules/alb`)

- Application Load Balancer for HTTP/HTTPS traffic
- Target group with health checks
- Security group for ALB access control
- Optional Route53 integration

### MongoDB Module (`./modules/mongodb`)

- MongoDB Atlas cluster setup
- Database user with appropriate permissions
- Network access configuration
- Pre-created collections for the application

### CloudWatch Module (`./modules/cloudwatch`)

- Log groups for application and ALB logs
- CloudWatch dashboard with key metrics
- Alarms for CPU, memory, and error monitoring

## Configuration Options

### Environment Variables

The ECS tasks receive these environment variables:

- `ENVIRONMENT`: Current environment (dev/staging/prod)
- `MONGODB_URI`: MongoDB connection string
- `JWT_SECRET`: Secret for JWT token generation
- `MAPBOX_ACCESS_TOKEN`: Mapbox API access token
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses

### Scaling Configuration

- **CPU**: 256 CPU units (0.25 vCPU)
- **Memory**: 512 MiB
- **Instances**: 2 (configurable via `app_count`)

### Security

- ECS tasks run in private subnets
- Security groups restrict traffic to necessary ports
- IAM roles follow least-privilege principle
- MongoDB Atlas network access controls

## Monitoring and Logging

### CloudWatch Dashboard

Access the dashboard in AWS Console to view:
- ECS service metrics (CPU, Memory)
- ALB metrics (Request count, Response time)
- Application error logs

### Log Groups

- **Application logs**: `/aws/ecs/rideshare-{environment}`
- **ALB logs**: `/aws/alb/rideshare-{environment}`

### Alarms

- CPU utilization > 80%
- Memory utilization > 80%
- ALB 5XX errors > 10

## Cost Optimization

- **MongoDB Atlas**: Uses M0 (free tier) for development
- **ECS Fargate**: Pay-per-use pricing
- **NAT Gateways**: Consider using NAT instances for dev environments
- **Log Retention**: 30 days by default (adjustable)

## Development Workflow

### Local Development

1. Use `docker-compose.yml` in the parent directory for local development
2. Set environment variables in `.env` file
3. Run the API locally with `uvicorn app.main:app --reload`

### Infrastructure Updates

1. Modify the Terraform configuration
2. Run `terraform plan` to review changes
3. Apply with `terraform apply`

### Destroying Infrastructure

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources. Ensure you have backups of important data.

## Troubleshooting

### Common Issues

1. **ECS Tasks Not Starting**: Check IAM roles and security groups
2. **MongoDB Connection Issues**: Verify network access and credentials
3. **ALB Health Check Failures**: Ensure `/health` endpoint is implemented

### Debug Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster rideshare-dev-cluster --services rideshare-dev-service

# View CloudWatch logs
aws logs tail /aws/ecs/rideshare-dev --follow

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Security Considerations

- All sensitive values are marked as `sensitive` in Terraform
- Use AWS Secrets Manager for production secrets
- Enable VPC Flow Logs for network monitoring
- Consider WAF for additional security layers
- Regular security updates for base images

## Support

For infrastructure-related issues:

1. Check CloudWatch logs and metrics
2. Review Terraform plan output
3. Verify AWS service quotas and limits
4. Consult AWS documentation for specific services

## License

This infrastructure code is part of the RideShare project for MSc Software Engineering at Kingston University London.
