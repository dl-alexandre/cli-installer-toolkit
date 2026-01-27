#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
AWS CloudWatch Metrics Helper - Query and export CloudWatch metrics.

Usage:
    uv run scripts/aws_metrics.py <command> [options]

Commands:
    list [namespace]                    List available metrics
    get <metric> [options]              Get specific metric data
    alarms [state]                      List CloudWatch alarms
    ecs <cluster> [service] [hours]     Get ECS service metrics
    ec2 <instance-id> [hours]           Get EC2 instance metrics
    rds <db-identifier> [hours]         Get RDS instance metrics
    export [output-file] [hours]        Export metrics to JSON
"""

import argparse
import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"


DEFAULT_PERIOD = 300
DEFAULT_HOURS = 1


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


def run_aws_command(args: list[str], timeout: int = 60) -> CommandResult:
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


def get_time_range(hours: int) -> tuple[str, str]:
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(hours=hours)
    return (
        start_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        end_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
    )


def list_metrics(namespace: Optional[str] = None) -> int:
    print_header("CloudWatch Metrics")

    if not namespace:
        print("Common namespaces:")
        namespaces = [
            ("AWS/EC2", "EC2 instances"),
            ("AWS/ECS", "ECS services"),
            ("AWS/Lambda", "Lambda functions"),
            ("AWS/RDS", "RDS databases"),
            ("AWS/ELB", "Classic Load Balancers"),
            ("AWS/ApplicationELB", "Application Load Balancers"),
            ("AWS/NetworkELB", "Network Load Balancers"),
            ("AWS/S3", "S3 buckets"),
            ("AWS/SQS", "SQS queues"),
            ("AWS/SNS", "SNS topics"),
            ("AWS/DynamoDB", "DynamoDB tables"),
        ]
        for ns, desc in namespaces:
            print(f"  {ns:25} - {desc}")
        print()
        print("Usage: aws_metrics.py list <namespace>")
        return 0

    print_info(f"Listing metrics in namespace: {namespace}")
    print()

    result = run_aws_command([
        "cloudwatch", "list-metrics",
        "--namespace", namespace,
        "--query", "Metrics[*].[MetricName,Dimensions[0].Name,Dimensions[0].Value]",
        "--output", "table",
    ])

    if result.success:
        print(result.stdout)
    else:
        print_error(f"Failed to list metrics: {result.stderr}")
        return 1

    return 0


def get_metric(
    metric_name: str,
    namespace: str = "AWS/EC2",
    dimension_name: Optional[str] = None,
    dimension_value: Optional[str] = None,
    hours: int = DEFAULT_HOURS,
    period: int = DEFAULT_PERIOD,
) -> int:
    print_header(f"CloudWatch Metric: {metric_name}")

    start_time, end_time = get_time_range(hours)

    print_info(f"Namespace: {namespace}")
    print_info(f"Period: {period}s")
    print_info(f"Time range: {start_time} to {end_time}")

    cmd = [
        "cloudwatch", "get-metric-statistics",
        "--namespace", namespace,
        "--metric-name", metric_name,
        "--start-time", start_time,
        "--end-time", end_time,
        "--period", str(period),
        "--statistics", "Average", "Minimum", "Maximum",
        "--query", "sort_by(Datapoints, &Timestamp)[*].[Timestamp,Average,Minimum,Maximum]",
        "--output", "table",
    ]

    if dimension_name and dimension_value:
        cmd.extend(["--dimensions", f"Name={dimension_name},Value={dimension_value}"])
        print_info(f"Dimension: {dimension_name}={dimension_value}")

    print()

    result = run_aws_command(cmd)
    if result.success:
        print(result.stdout)
    else:
        print_error(f"Failed to get metric: {result.stderr}")
        return 1

    return 0


def list_alarms(state: Optional[str] = None) -> int:
    print_header("CloudWatch Alarms")

    if state:
        print_info(f"Filtering by state: {state}")

    cmd = [
        "cloudwatch", "describe-alarms",
        "--query", "MetricAlarms[*].[AlarmName,StateValue,MetricName,Namespace]",
        "--output", "table",
    ]

    if state:
        cmd.extend(["--state-value", state])

    print()

    result = run_aws_command(cmd)
    if result.success:
        print(result.stdout)
    else:
        print_error(f"Failed to list alarms: {result.stderr}")
        return 1

    print()

    counts = {}
    for s in ["ALARM", "OK", "INSUFFICIENT_DATA"]:
        count_result = run_aws_command([
            "cloudwatch", "describe-alarms",
            "--state-value", s,
            "--query", "length(MetricAlarms)",
            "--output", "text",
        ])
        counts[s] = count_result.stdout.strip() if count_result.success else "?"

    print("Summary:")
    alarm_count = counts.get("ALARM", "0")
    if alarm_count != "0":
        print(f"  {Colors.RED}ALARM: {alarm_count}{Colors.NC}")
    else:
        print(f"  ALARM: 0")
    print(f"  OK: {counts.get('OK', '?')}")
    print(f"  INSUFFICIENT_DATA: {counts.get('INSUFFICIENT_DATA', '?')}")

    return 0


def get_ecs_metrics(cluster: str, service: Optional[str] = None, hours: int = DEFAULT_HOURS) -> int:
    print_header(f"ECS Metrics: {cluster}")

    start_time, end_time = get_time_range(hours)

    if not service:
        print("Services in cluster:")
        result = run_aws_command([
            "ecs", "list-services",
            "--cluster", cluster,
            "--query", "serviceArns[*]",
            "--output", "json",
        ])
        if result.success:
            try:
                services = json.loads(result.stdout)
                for svc_arn in services:
                    svc_name = svc_arn.split("/")[-1]
                    print(f"  - {svc_name}")
            except json.JSONDecodeError:
                print_error("Failed to parse services response")
        else:
            print_error(f"Failed to list services: {result.stderr}")
        print()
        print(f"Usage: aws_metrics.py ecs {cluster} <service-name>")
        return 0

    print_info(f"Service: {service}")
    print()

    for metric, label in [("CPUUtilization", "CPU Utilization"), ("MemoryUtilization", "Memory Utilization")]:
        print(f"{label}:")
        result = run_aws_command([
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/ECS",
            "--metric-name", metric,
            "--dimensions",
            f"Name=ClusterName,Value={cluster}",
            f"Name=ServiceName,Value={service}",
            "--start-time", start_time,
            "--end-time", end_time,
            "--period", "300",
            "--statistics", "Average",
            "--query", "sort_by(Datapoints, &Timestamp)[-5:].[Timestamp,Average]",
            "--output", "table",
        ])
        if result.success:
            print(result.stdout)
        else:
            print_warning(f"No data for {metric}")
        print()

    return 0


def get_ec2_metrics(instance_id: str, hours: int = DEFAULT_HOURS) -> int:
    print_header(f"EC2 Metrics: {instance_id}")

    start_time, end_time = get_time_range(hours)

    metrics = [
        ("CPUUtilization", "CPU Utilization", "Average"),
        ("NetworkIn", "Network In (bytes)", "Sum"),
        ("NetworkOut", "Network Out (bytes)", "Sum"),
    ]

    for metric, label, stat in metrics:
        print(f"{label}:")
        result = run_aws_command([
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/EC2",
            "--metric-name", metric,
            "--dimensions", f"Name=InstanceId,Value={instance_id}",
            "--start-time", start_time,
            "--end-time", end_time,
            "--period", "300",
            "--statistics", stat,
            "--query", f"sort_by(Datapoints, &Timestamp)[-5:].[Timestamp,{stat}]",
            "--output", "table",
        ])
        if result.success:
            print(result.stdout)
        else:
            print_warning(f"No data for {metric}")
        print()

    return 0


def get_rds_metrics(db_identifier: str, hours: int = DEFAULT_HOURS) -> int:
    print_header(f"RDS Metrics: {db_identifier}")

    start_time, end_time = get_time_range(hours)

    metrics = [
        ("CPUUtilization", "CPU Utilization"),
        ("DatabaseConnections", "Database Connections"),
        ("FreeStorageSpace", "Free Storage Space (bytes)"),
    ]

    for metric, label in metrics:
        print(f"{label}:")
        result = run_aws_command([
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/RDS",
            "--metric-name", metric,
            "--dimensions", f"Name=DBInstanceIdentifier,Value={db_identifier}",
            "--start-time", start_time,
            "--end-time", end_time,
            "--period", "300",
            "--statistics", "Average",
            "--query", "sort_by(Datapoints, &Timestamp)[-5:].[Timestamp,Average]",
            "--output", "table",
        ])
        if result.success:
            print(result.stdout)
        else:
            print_warning(f"No data for {metric}")
        print()

    return 0


def export_metrics(output_file: str = "metrics.json", hours: int = 24) -> int:
    print_header("Exporting Metrics")

    start_time, end_time = get_time_range(hours)

    print_info(f"Time range: {start_time} to {end_time}")
    print_info(f"Output file: {output_file}")

    queries = [
        {
            "Id": "ec2_cpu",
            "MetricStat": {
                "Metric": {
                    "Namespace": "AWS/EC2",
                    "MetricName": "CPUUtilization",
                },
                "Period": 3600,
                "Stat": "Average",
            },
            "ReturnData": True,
        },
        {
            "Id": "ecs_cpu",
            "MetricStat": {
                "Metric": {
                    "Namespace": "AWS/ECS",
                    "MetricName": "CPUUtilization",
                },
                "Period": 3600,
                "Stat": "Average",
            },
            "ReturnData": True,
        },
        {
            "Id": "rds_cpu",
            "MetricStat": {
                "Metric": {
                    "Namespace": "AWS/RDS",
                    "MetricName": "CPUUtilization",
                },
                "Period": 3600,
                "Stat": "Average",
            },
            "ReturnData": True,
        },
        {
            "Id": "lambda_invocations",
            "MetricStat": {
                "Metric": {
                    "Namespace": "AWS/Lambda",
                    "MetricName": "Invocations",
                },
                "Period": 3600,
                "Stat": "Sum",
            },
            "ReturnData": True,
        },
    ]

    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(queries, f)
        queries_file = f.name

    try:
        result = run_aws_command([
            "cloudwatch", "get-metric-data",
            "--metric-data-queries", f"file://{queries_file}",
            "--start-time", start_time,
            "--end-time", end_time,
            "--output", "json",
        ], timeout=120)

        if result.success:
            with open(output_file, "w") as f:
                f.write(result.stdout)
            print_success(f"Metrics exported to {output_file}")
            file_size = Path(output_file).stat().st_size
            print_info(f"File size: {file_size} bytes")
            return 0
        else:
            print_error(f"Failed to export metrics: {result.stderr}")
            return 1
    finally:
        Path(queries_file).unlink(missing_ok=True)


def list_resources(resource_type: str) -> None:
    if resource_type == "ec2":
        print("Running instances:")
        result = run_aws_command([
            "ec2", "describe-instances",
            "--filters", "Name=instance-state-name,Values=running",
            "--query", "Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]",
            "--output", "text",
        ])
        if result.success:
            print(result.stdout)
    elif resource_type == "ecs":
        print("Available clusters:")
        result = run_aws_command([
            "ecs", "list-clusters",
            "--query", "clusterArns[*]",
            "--output", "text",
        ])
        if result.success:
            for arn in result.stdout.strip().split():
                print(f"  {arn.split('/')[-1]}")
    elif resource_type == "rds":
        print("RDS instances:")
        result = run_aws_command([
            "rds", "describe-db-instances",
            "--query", "DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceStatus]",
            "--output", "text",
        ])
        if result.success:
            print(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="AWS CloudWatch Metrics Helper",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s list AWS/ECS
    %(prog)s get CPUUtilization --namespace AWS/EC2 --dimension InstanceId=i-1234567890
    %(prog)s alarms ALARM
    %(prog)s ecs production-cluster my-service --hours 24
    %(prog)s ec2 i-1234567890abcdef0 --hours 6
    %(prog)s rds mydb-instance --hours 12
    %(prog)s export metrics.json --hours 24
        """,
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    list_parser = subparsers.add_parser("list", help="List available metrics")
    list_parser.add_argument("namespace", nargs="?", help="CloudWatch namespace")

    get_parser = subparsers.add_parser("get", help="Get specific metric data")
    get_parser.add_argument("metric", help="Metric name")
    get_parser.add_argument("--namespace", "-n", default="AWS/EC2", help="CloudWatch namespace")
    get_parser.add_argument("--dimension", "-d", help="Dimension in Name=Value format")
    get_parser.add_argument("--hours", type=int, default=DEFAULT_HOURS, help="Hours of data")
    get_parser.add_argument("--period", type=int, default=DEFAULT_PERIOD, help="Period in seconds")

    alarms_parser = subparsers.add_parser("alarms", help="List CloudWatch alarms")
    alarms_parser.add_argument("state", nargs="?", choices=["ALARM", "OK", "INSUFFICIENT_DATA"])

    ecs_parser = subparsers.add_parser("ecs", help="Get ECS service metrics")
    ecs_parser.add_argument("cluster", help="ECS cluster name")
    ecs_parser.add_argument("service", nargs="?", help="ECS service name")
    ecs_parser.add_argument("--hours", type=int, default=DEFAULT_HOURS, help="Hours of data")

    ec2_parser = subparsers.add_parser("ec2", help="Get EC2 instance metrics")
    ec2_parser.add_argument("instance_id", help="EC2 instance ID")
    ec2_parser.add_argument("--hours", type=int, default=DEFAULT_HOURS, help="Hours of data")

    rds_parser = subparsers.add_parser("rds", help="Get RDS instance metrics")
    rds_parser.add_argument("db_identifier", help="RDS DB instance identifier")
    rds_parser.add_argument("--hours", type=int, default=DEFAULT_HOURS, help="Hours of data")

    export_parser = subparsers.add_parser("export", help="Export metrics to JSON")
    export_parser.add_argument("output_file", nargs="?", default="metrics.json", help="Output file")
    export_parser.add_argument("--hours", type=int, default=24, help="Hours of data")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    if args.command == "list":
        return list_metrics(args.namespace)
    elif args.command == "get":
        dim_name, dim_value = None, None
        if args.dimension:
            parts = args.dimension.split("=", 1)
            if len(parts) == 2:
                dim_name, dim_value = parts
        return get_metric(
            args.metric,
            args.namespace,
            dim_name,
            dim_value,
            args.hours,
            args.period,
        )
    elif args.command == "alarms":
        return list_alarms(args.state)
    elif args.command == "ecs":
        return get_ecs_metrics(args.cluster, args.service, args.hours)
    elif args.command == "ec2":
        return get_ec2_metrics(args.instance_id, args.hours)
    elif args.command == "rds":
        return get_rds_metrics(args.db_identifier, args.hours)
    elif args.command == "export":
        return export_metrics(args.output_file, args.hours)

    return 0


if __name__ == "__main__":
    sys.exit(main())
