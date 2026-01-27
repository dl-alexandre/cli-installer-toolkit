#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
AWS CLI Check - Verify AWS CLI setup for dash monitoring.

Usage:
    uv run scripts/aws_check.py [command]

Commands:
    all          Run all checks (default)
    identity     Check AWS identity/credentials
    permissions  Test required permissions for dash
    services     Discover AWS services
    config       Show AWS configuration
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"


def print_header(text: str) -> None:
    print(f"\n{Colors.BLUE}{'━' * 60}{Colors.NC}")
    print(f"{Colors.BLUE}  {text}{Colors.NC}")
    print(f"{Colors.BLUE}{'━' * 60}{Colors.NC}\n")


def print_success(text: str) -> None:
    print(f"{Colors.GREEN}✓{Colors.NC} {text}")


def print_error(text: str) -> None:
    print(f"{Colors.RED}✗{Colors.NC} {text}")


def print_warning(text: str) -> None:
    print(f"{Colors.YELLOW}!{Colors.NC} {text}")


def print_info(text: str) -> None:
    print(f"{Colors.BLUE}→{Colors.NC} {text}")


@dataclass
class CommandResult:
    success: bool
    stdout: str
    stderr: str
    returncode: int


def run_aws_command(args: list[str], timeout: int = 30) -> CommandResult:
    try:
        result = subprocess.run(
            ["aws"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return CommandResult(
            success=result.returncode == 0,
            stdout=result.stdout,
            stderr=result.stderr,
            returncode=result.returncode,
        )
    except subprocess.TimeoutExpired:
        return CommandResult(
            success=False,
            stdout="",
            stderr="Command timed out",
            returncode=-1,
        )
    except FileNotFoundError:
        return CommandResult(
            success=False,
            stdout="",
            stderr="AWS CLI not found",
            returncode=-1,
        )


def check_cli_installed() -> bool:
    print_header("AWS CLI Installation")

    aws_path = shutil.which("aws")
    if not aws_path:
        print_error("AWS CLI not found in PATH")
        print("\nInstall with:")
        print("  macOS:  brew install awscli")
        print("  Linux:  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'")
        return False

    result = run_aws_command(["--version"])
    if result.success:
        version = result.stdout.strip()
        print_success(f"AWS CLI installed: {version}")
        print_info(f"Path: {aws_path}")
        return True

    print_error(f"Failed to get AWS CLI version: {result.stderr}")
    return False


def check_identity() -> bool:
    print_header("AWS Identity")

    result = run_aws_command(["sts", "get-caller-identity", "--output", "json"])
    if not result.success:
        print_error("Failed to get caller identity")
        print(result.stderr)
        print("\nCheck your credentials:")
        print("  aws configure")
        print("  aws configure --profile <profile-name>")
        return False

    try:
        identity = json.loads(result.stdout)
        print_success("Authenticated successfully")
        print_info(f"Account:  {identity.get('Account', 'N/A')}")
        print_info(f"ARN:      {identity.get('Arn', 'N/A')}")
        print_info(f"User ID:  {identity.get('UserId', 'N/A')}")

        if profile := os.environ.get("AWS_PROFILE"):
            print_info(f"Profile:  {profile}")

        region_result = run_aws_command(["configure", "get", "region"])
        region = region_result.stdout.strip() if region_result.success else "not set"
        print_info(f"Region:   {region}")

        return True
    except json.JSONDecodeError:
        print_error("Invalid JSON response from AWS CLI")
        return False


def check_permissions() -> bool:
    print_header("Dash Monitoring Permissions")

    required_tests = {
        "ecs:ListClusters": ["ecs", "list-clusters", "--max-results", "1"],
        "ec2:DescribeInstances": ["ec2", "describe-instances", "--max-results", "1"],
        "ec2:DescribeRegions": ["ec2", "describe-regions", "--max-results", "1"],
        "lambda:ListFunctions": ["lambda", "list-functions", "--max-items", "1"],
        "cloudwatch:DescribeAlarms": ["cloudwatch", "describe-alarms", "--max-records", "1"],
        "cloudwatch:ListMetrics": ["cloudwatch", "list-metrics", "--namespace", "AWS/EC2"],
        "rds:DescribeDBInstances": ["rds", "describe-db-instances", "--max-records", "1"],
        "elbv2:DescribeLoadBalancers": ["elbv2", "describe-load-balancers", "--page-size", "1"],
        "s3:ListBuckets": ["s3api", "list-buckets"],
        "sts:GetCallerIdentity": ["sts", "get-caller-identity"],
    }

    passed = 0
    failed = 0

    for permission, cmd in required_tests.items():
        result = run_aws_command(cmd)
        if result.success:
            print_success(permission)
            passed += 1
        else:
            print_error(permission)
            failed += 1

    print()

    optional_tests = {
        "ce:GetCostAndUsage": [
            "ce", "get-cost-and-usage",
            "--time-period", "Start=2024-01-01,End=2024-01-02",
            "--granularity", "DAILY",
            "--metrics", "BlendedCost",
        ],
        "securityhub:GetFindings": ["securityhub", "get-findings", "--max-results", "1"],
        "guardduty:ListDetectors": ["guardduty", "list-detectors", "--max-results", "1"],
        "elasticbeanstalk:DescribeEnvironments": [
            "elasticbeanstalk", "describe-environments", "--max-records", "1"
        ],
    }

    print_info("Optional permissions (may require service activation):")
    for permission, cmd in optional_tests.items():
        result = run_aws_command(cmd)
        if result.success:
            print_success(permission)
        else:
            print_warning(f"{permission} (not available or not enabled)")

    print()
    print(f"Required permissions: {passed} passed, {failed} failed")

    return failed == 0


def discover_services() -> None:
    print_header("Service Discovery")

    print("ECS Clusters:")
    result = run_aws_command(["ecs", "list-clusters", "--query", "clusterArns[*]", "--output", "json"])
    if result.success:
        try:
            clusters = json.loads(result.stdout)
            if clusters:
                for cluster_arn in clusters:
                    cluster_name = cluster_arn.split("/")[-1]
                    print_info(cluster_name)

                    svc_result = run_aws_command([
                        "ecs", "list-services",
                        "--cluster", cluster_arn,
                        "--query", "serviceArns[*]",
                        "--output", "json",
                    ])
                    if svc_result.success:
                        services = json.loads(svc_result.stdout)
                        for service_arn in services:
                            service_name = service_arn.split("/")[-1]
                            print(f"    - {service_name}")
            else:
                print_warning("No ECS clusters found")
        except json.JSONDecodeError:
            print_error("Failed to parse ECS clusters response")
    else:
        print_error("Failed to list ECS clusters")

    print()
    print("EC2 Instances (running):")
    result = run_aws_command([
        "ec2", "describe-instances",
        "--filters", "Name=instance-state-name,Values=running",
        "--query", "Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType]",
        "--output", "json",
    ])
    if result.success:
        try:
            reservations = json.loads(result.stdout)
            instances = [inst for res in reservations for inst in res]
            if instances:
                for inst in instances:
                    instance_id, name, instance_type = inst
                    name = name or "unnamed"
                    print_info(f"{instance_id} - {name} ({instance_type})")
            else:
                print_warning("No running EC2 instances found")
        except json.JSONDecodeError:
            print_error("Failed to parse EC2 instances response")
    else:
        print_error("Failed to describe EC2 instances")

    print()
    print("Lambda Functions:")
    result = run_aws_command([
        "lambda", "list-functions",
        "--query", "Functions[*].[FunctionName,Runtime]",
        "--output", "json",
    ])
    if result.success:
        try:
            functions = json.loads(result.stdout)
            if functions:
                for i, func in enumerate(functions[:10]):
                    name, runtime = func
                    print_info(f"{name} ({runtime})")
                if len(functions) > 10:
                    print(f"    ... and {len(functions) - 10} more")
            else:
                print_warning("No Lambda functions found")
        except json.JSONDecodeError:
            print_error("Failed to parse Lambda functions response")
    else:
        print_error("Failed to list Lambda functions")

    print()
    print("Load Balancers:")
    result = run_aws_command([
        "elbv2", "describe-load-balancers",
        "--query", "LoadBalancers[*].[LoadBalancerName,Type,State.Code]",
        "--output", "json",
    ])
    if result.success:
        try:
            lbs = json.loads(result.stdout)
            if lbs:
                for lb in lbs:
                    name, lb_type, state = lb
                    print_info(f"{name} ({lb_type}) - {state}")
            else:
                print_warning("No load balancers found")
        except json.JSONDecodeError:
            print_error("Failed to parse load balancers response")
    else:
        print_error("Failed to describe load balancers")

    print()
    print("RDS Instances:")
    result = run_aws_command([
        "rds", "describe-db-instances",
        "--query", "DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceStatus]",
        "--output", "json",
    ])
    if result.success:
        try:
            dbs = json.loads(result.stdout)
            if dbs:
                for db in dbs:
                    identifier, engine, status = db
                    print_info(f"{identifier} ({engine}) - {status}")
            else:
                print_warning("No RDS instances found")
        except json.JSONDecodeError:
            print_error("Failed to parse RDS instances response")
    else:
        print_error("Failed to describe RDS instances")


def show_config() -> None:
    print_header("AWS Configuration")

    config_path = Path.home() / ".aws" / "config"
    credentials_path = Path.home() / ".aws" / "credentials"

    print("Configuration files:")
    if config_path.exists():
        print_success("~/.aws/config exists")
        print("  Profiles:")
        with open(config_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    profile = line.replace("[profile ", "").replace("[", "").replace("]", "")
                    print(f"  - {profile}")
    else:
        print_warning("~/.aws/config not found")

    print()
    if credentials_path.exists():
        print_success("~/.aws/credentials exists")
        print("  Profiles:")
        with open(credentials_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    profile = line.replace("[", "").replace("]", "")
                    print(f"  - {profile}")
    else:
        print_warning("~/.aws/credentials not found")

    print()
    print("Environment variables:")
    env_vars = {
        "AWS_PROFILE": os.environ.get("AWS_PROFILE"),
        "AWS_DEFAULT_REGION": os.environ.get("AWS_DEFAULT_REGION"),
        "AWS_ACCESS_KEY_ID": "***" if os.environ.get("AWS_ACCESS_KEY_ID") else None,
        "AWS_SECRET_ACCESS_KEY": "***" if os.environ.get("AWS_SECRET_ACCESS_KEY") else None,
    }

    for var, value in env_vars.items():
        if value:
            print_info(f"{var}={value}")
        else:
            print_warning(f"{var} not set")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="AWS CLI Check - Verify AWS CLI setup for dash monitoring",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s                    # Run all checks
    %(prog)s identity           # Just check identity
    %(prog)s permissions        # Test dash permissions

Environment Variables:
    AWS_PROFILE             AWS profile to use
    AWS_DEFAULT_REGION      Default AWS region
        """,
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="all",
        choices=["all", "identity", "permissions", "services", "config"],
        help="Command to run (default: all)",
    )

    args = parser.parse_args()

    if args.command == "all":
        if not check_cli_installed():
            return 1
        if not check_identity():
            return 1
        show_config()
        check_permissions()
        discover_services()
    elif args.command == "identity":
        if not check_cli_installed():
            return 1
        if not check_identity():
            return 1
    elif args.command == "permissions":
        if not check_cli_installed():
            return 1
        if not check_identity():
            return 1
        if not check_permissions():
            return 1
    elif args.command == "services":
        if not check_cli_installed():
            return 1
        if not check_identity():
            return 1
        discover_services()
    elif args.command == "config":
        if not check_cli_installed():
            return 1
        show_config()

    return 0


if __name__ == "__main__":
    sys.exit(main())
