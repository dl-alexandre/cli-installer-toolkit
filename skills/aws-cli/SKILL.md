---
name: aws-cli
description: Expert guidance on AWS CLI v2 for managing AWS services from the command line. Integrates with the dash monitoring dashboard. Use when developers mention: (1) aws command or AWS CLI, (2) CloudWatch metrics or alarms, (3) ECS/EC2/Lambda service discovery, (4) S3 bucket operations, (5) Cost Explorer queries, (6) Security Hub or GuardDuty findings, (7) configuring AWS credentials or profiles, (8) dash AWS monitoring setup.
---

# AWS CLI v2

## Overview

The AWS Command Line Interface (AWS CLI) is a unified tool to manage AWS services from the command line. Version 2 is the current major version with improved installers, new configuration options, and native support for AWS IAM Identity Center (SSO).

**Official Documentation**: https://docs.aws.amazon.com/cli/latest/userguide/

## Configuration

### Quick Setup

```bash
aws configure
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name: us-west-2
# Default output format: json
```

### Named Profiles

```bash
aws configure --profile production
aws configure --profile development

# Use a profile
aws s3 ls --profile production
export AWS_PROFILE=production
```

### Configuration Files

```ini
# ~/.aws/credentials
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[production]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
```

```ini
# ~/.aws/config
[default]
region = us-west-2
output = json

[profile production]
region = us-east-1
output = json

[profile sso-user]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = ReadOnlyAccess
region = us-west-2
```

### Environment Variables

```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-west-2
export AWS_PROFILE=production
export AWS_SESSION_TOKEN=...  # For temporary credentials
```

### IAM Identity Center (SSO)

```bash
aws configure sso
# SSO session name: my-sso
# SSO start URL: https://my-sso-portal.awsapps.com/start
# SSO region: us-east-1
# SSO registration scopes: sso:account:access

# Login to SSO
aws sso login --profile my-sso-profile
```

## Core Commands

### Identity and Access

```bash
aws sts get-caller-identity                    # Who am I?
aws iam list-users                             # List IAM users
aws iam get-user --user-name alice             # Get user details
aws iam list-roles                             # List IAM roles
```

### EC2

```bash
aws ec2 describe-instances                     # List all instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table
aws ec2 start-instances --instance-ids i-1234567890abcdef0
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
aws ec2 describe-regions --all-regions         # List all regions
```

### ECS

```bash
aws ecs list-clusters                          # List ECS clusters
aws ecs list-services --cluster my-cluster     # List services in cluster
aws ecs describe-services --cluster my-cluster --services my-service
aws ecs list-tasks --cluster my-cluster --service-name my-service
aws ecs describe-tasks --cluster my-cluster --tasks <task-arn>
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment
```

### Lambda

```bash
aws lambda list-functions                      # List all functions
aws lambda get-function --function-name my-function
aws lambda invoke --function-name my-function output.json
aws lambda update-function-code --function-name my-function --zip-file fileb://function.zip
```

### S3

```bash
aws s3 ls                                      # List buckets
aws s3 ls s3://my-bucket/                      # List bucket contents
aws s3 cp file.txt s3://my-bucket/             # Upload file
aws s3 cp s3://my-bucket/file.txt ./           # Download file
aws s3 sync ./local-dir s3://my-bucket/prefix/ # Sync directory
aws s3 rm s3://my-bucket/file.txt              # Delete file
aws s3 rb s3://my-bucket --force               # Delete bucket
aws s3api get-bucket-location --bucket my-bucket
```

### CloudWatch

```bash
# List alarms
aws cloudwatch describe-alarms
aws cloudwatch describe-alarms --state-value ALARM

# Get metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average

# List metrics
aws cloudwatch list-metrics --namespace AWS/ECS

# Put metric data
aws cloudwatch put-metric-data \
  --namespace "Custom/MyApp" \
  --metric-name "RequestCount" \
  --value 100
```

### RDS

```bash
aws rds describe-db-instances                  # List RDS instances
aws rds describe-db-clusters                   # List Aurora clusters
aws rds describe-db-snapshots                  # List snapshots
aws rds create-db-snapshot --db-instance-identifier mydb --db-snapshot-identifier mydb-snapshot
```

### Cost Explorer

```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics "BlendedCost" "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE
```

### Security Hub

```bash
aws securityhub get-findings --max-results 100
aws securityhub get-findings --filters '{"SeverityNormalized": [{"Gte": 70}]}'
aws securityhub describe-standards
```

### GuardDuty

```bash
aws guardduty list-detectors
aws guardduty list-findings --detector-id <detector-id>
aws guardduty get-findings --detector-id <detector-id> --finding-ids <finding-id>
```

### Elastic Load Balancing

```bash
aws elbv2 describe-load-balancers              # List ALB/NLB
aws elbv2 describe-target-groups --load-balancer-arn <arn>
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Elastic Beanstalk

```bash
aws elasticbeanstalk describe-environments
aws elasticbeanstalk describe-environment-health --environment-name my-env --attribute-names All
```

## Integration with Dash Monitoring

The `dash` monitoring dashboard uses AWS CLI for service discovery and metrics collection. Configuration is in `config/aws-monitoring.yaml`.

### Configuration Example

```yaml
# config/aws-monitoring.yaml
aws:
  region: "us-west-2"
  credentials:
    use_iam_role: true      # Use EC2 instance role or default chain
    profile: ""             # Or specify a named profile
    access_key_id: ""       # Or explicit credentials
    secret_access_key: ""

service_stability:
  discovery:
    enabled: true
    use_aws_cli: true       # Enable CLI-based discovery
    clusters:
      - name: "production-cluster"
        region: "us-west-2"
    ec2_filters:
      - name: "tag:Environment"
        values: ["prod"]
    discover_elastic_beanstalk: true
    discover_lambda: true
```

### How Dash Uses AWS CLI

The `AWSCLIExecutor` in dash executes AWS CLI commands for:

1. **Service Discovery**: ECS services, EC2 instances, Lambda functions, Elastic Beanstalk environments
2. **CloudWatch Metrics**: CPU, memory, request counts, latency
3. **Alarms**: CloudWatch alarm states
4. **Cost Data**: Daily/monthly cost breakdowns
5. **Security**: Security Hub findings, GuardDuty detections
6. **Load Balancer Health**: Target group health status

### Verifying CLI Access for Dash

```bash
# Test identity
aws sts get-caller-identity

# Test ECS discovery
aws ecs list-clusters
aws ecs list-services --cluster production-cluster

# Test CloudWatch access
aws cloudwatch describe-alarms --state-value ALARM

# Test Cost Explorer (requires activation)
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-7d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost
```

### Required IAM Permissions for Dash

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "lambda:ListFunctions",
        "lambda:GetFunction",
        "elasticbeanstalk:DescribeEnvironments",
        "elasticbeanstalk:DescribeEnvironmentHealth",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "ce:GetCostAndUsage",
        "securityhub:GetFindings",
        "guardduty:ListDetectors",
        "guardduty:ListFindings",
        "guardduty:GetFindings",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## Common Workflows

### Service Discovery Script

```bash
# Discover all running services across ECS clusters
for cluster in $(aws ecs list-clusters --query 'clusterArns[*]' --output text); do
  echo "Cluster: $cluster"
  aws ecs list-services --cluster "$cluster" --query 'serviceArns[*]' --output table
done
```

### Health Check All Load Balancers

```bash
for lb in $(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text); do
  echo "Load Balancer: $lb"
  for tg in $(aws elbv2 describe-target-groups --load-balancer-arn "$lb" --query 'TargetGroups[*].TargetGroupArn' --output text); do
    aws elbv2 describe-target-health --target-group-arn "$tg" \
      --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
  done
done
```

### Export CloudWatch Metrics

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://queries.json \
  --start-time $(date -v-1H -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --output json > metrics.json
```

### Cost Report

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-30d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[*].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' \
  --output table
```

## Output Formats

```bash
aws ec2 describe-instances --output json       # JSON (default)
aws ec2 describe-instances --output text       # Tab-separated
aws ec2 describe-instances --output table      # ASCII table
aws ec2 describe-instances --output yaml       # YAML
```

### JMESPath Queries

```bash
# Get instance IDs only
aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' --output text

# Filter and format
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Complex filtering
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[?State.Name==`running`].[InstanceId,InstanceType]' \
  --output table
```

## Troubleshooting

### Credential Issues

```bash
# Check current identity
aws sts get-caller-identity

# Debug credential chain
AWS_DEBUG=1 aws sts get-caller-identity

# Clear cached credentials
rm -rf ~/.aws/cli/cache/*
```

### Region Issues

```bash
# Check configured region
aws configure get region

# Override region
aws ec2 describe-instances --region us-east-1
```

### Timeout Issues

```bash
# Increase timeout
aws configure set cli_read_timeout 60
aws configure set cli_connect_timeout 30

# Or via environment
export AWS_READ_TIMEOUT=60
export AWS_CONNECT_TIMEOUT=30
```

### Rate Limiting

```bash
# Configure retry mode
aws configure set retry_mode adaptive
aws configure set max_attempts 10
```

### Debug Mode

```bash
aws ec2 describe-instances --debug 2>&1 | head -100
```

## Helper Scripts

This skill includes Python helper scripts in the `scripts/` directory. Run with `uv run`:

### aws_check.py - Verify AWS CLI Setup

```bash
uv run ~/.claude/skills/aws-cli/scripts/aws_check.py              # Full diagnostic
uv run ~/.claude/skills/aws-cli/scripts/aws_check.py identity     # Check credentials
uv run ~/.claude/skills/aws-cli/scripts/aws_check.py permissions  # Test dash-required permissions
uv run ~/.claude/skills/aws-cli/scripts/aws_check.py services     # Discover AWS services
uv run ~/.claude/skills/aws-cli/scripts/aws_check.py config       # Show AWS configuration
```

### aws_metrics.py - CloudWatch Metrics Helper

```bash
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py list AWS/ECS
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py get CPUUtilization --namespace AWS/EC2 --dimension InstanceId=i-1234567890
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py alarms ALARM
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py ecs my-cluster my-service --hours 24
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py ec2 i-1234567890abcdef0 --hours 6
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py rds mydb-instance --hours 12
uv run ~/.claude/skills/aws-cli/scripts/aws_metrics.py export metrics.json --hours 24
```

## Resources

- [AWS CLI v2 User Guide](https://docs.aws.amazon.com/cli/latest/userguide/)
- [AWS CLI v2 Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)
- [AWS CLI GitHub Repository](https://github.com/aws/aws-cli)
- [JMESPath Tutorial](https://jmespath.org/tutorial.html)
- [IAM Policy Simulator](https://policysim.aws.amazon.com/)

## Installation Reference

### macOS

```bash
# Homebrew (recommended)
brew install awscli

# Official installer
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

### Linux

```bash
# x86_64
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# ARM64
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Docker

```bash
docker run --rm -it amazon/aws-cli --version
docker run --rm -it -v ~/.aws:/root/.aws amazon/aws-cli s3 ls
```

### Verify Installation

```bash
aws --version
# aws-cli/2.x.x Python/3.x.x Darwin/23.x.x source/arm64
```
