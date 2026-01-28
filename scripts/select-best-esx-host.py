#!/usr/bin/env python3
"""
Script: select-best-esx-host.py
Purpose: Query vSphere cluster and select ESXi host with most available resources

Requirements:
    pip install pyvmomi

Usage:
    export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
    export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
    export TF_VAR_vsphere_password="your-password"

    python3 select-best-esx-host.py --datacenter TAP_CPD1 --cluster CPD1_ESX7

Output:
    Returns the FQDN of the ESXi host with most available resources
"""

import argparse
import os
import sys
import ssl
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim


def get_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Select best ESXi host based on available resources"
    )
    parser.add_argument(
        "--datacenter", required=True, help="vSphere datacenter name (e.g., TAP_CPD1)"
    )
    parser.add_argument(
        "--cluster", required=True, help="vSphere cluster name (e.g., CPD1_ESX7)"
    )
    parser.add_argument(
        "--metric",
        choices=["cpu", "memory", "balanced"],
        default="balanced",
        help="Selection criteria: cpu, memory, or balanced (default: balanced)",
    )
    parser.add_argument(
        "--format",
        choices=["fqdn", "json"],
        default="fqdn",
        help="Output format: fqdn (default) or json",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    return parser.parse_args()


def get_vsphere_connection():
    """Establish connection to vSphere"""
    server = os.getenv("TF_VAR_vsphere_server")
    user = os.getenv("TF_VAR_vsphere_user")
    password = os.getenv("TF_VAR_vsphere_password")

    if not all([server, user, password]):
        print("ERROR: Missing required environment variables:", file=sys.stderr)
        print(
            "  TF_VAR_vsphere_server, TF_VAR_vsphere_user, TF_VAR_vsphere_password",
            file=sys.stderr,
        )
        sys.exit(1)

    # Disable SSL certificate verification (for self-signed certs)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    try:
        si = SmartConnect(host=server, user=user, pwd=password, sslContext=context)
        return si
    except Exception as e:
        print(f"ERROR: Failed to connect to vSphere: {e}", file=sys.stderr)
        sys.exit(1)


def find_cluster(si, datacenter_name, cluster_name):
    """Find cluster object in vSphere"""
    content = si.RetrieveContent()

    # Find datacenter
    for dc in content.rootFolder.childEntity:
        if hasattr(dc, "name") and dc.name == datacenter_name:
            # Find cluster
            for cluster in dc.hostFolder.childEntity:
                if (
                    isinstance(cluster, vim.ClusterComputeResource)
                    and cluster.name == cluster_name
                ):
                    return cluster

    print(
        f"ERROR: Cluster '{cluster_name}' not found in datacenter '{datacenter_name}'",
        file=sys.stderr,
    )
    sys.exit(1)


def get_host_resources(host):
    """Get resource information for a host"""
    try:
        # CPU information
        cpu_total_mhz = (
            host.hardware.cpuInfo.hz / 1000000 * host.hardware.cpuInfo.numCpuCores
        )
        cpu_usage_mhz = host.summary.quickStats.overallCpuUsage
        cpu_available_mhz = cpu_total_mhz - cpu_usage_mhz
        cpu_available_percent = (cpu_available_mhz / cpu_total_mhz) * 100

        # Memory information
        memory_total_mb = host.hardware.memorySize / (1024 * 1024)
        memory_usage_mb = host.summary.quickStats.overallMemoryUsage
        memory_available_mb = memory_total_mb - memory_usage_mb
        memory_available_percent = (memory_available_mb / memory_total_mb) * 100

        return {
            "name": host.name,
            "connection_state": str(host.runtime.connectionState),
            "power_state": str(host.runtime.powerState),
            "cpu_total_mhz": cpu_total_mhz,
            "cpu_usage_mhz": cpu_usage_mhz,
            "cpu_available_mhz": cpu_available_mhz,
            "cpu_available_percent": cpu_available_percent,
            "memory_total_mb": memory_total_mb,
            "memory_usage_mb": memory_usage_mb,
            "memory_available_mb": memory_available_mb,
            "memory_available_percent": memory_available_percent,
            "num_vms": len(host.vm),
        }
    except Exception as e:
        print(
            f"WARNING: Failed to get resources for host {host.name}: {e}",
            file=sys.stderr,
        )
        return None


def select_best_host(cluster, metric, verbose=False):
    """Select the best host based on specified metric"""
    hosts_info = []

    for host in cluster.host:
        # Skip hosts that are not connected or powered off
        if host.runtime.connectionState != vim.HostSystemConnectionState.connected:
            if verbose:
                print(f"Skipping {host.name}: not connected", file=sys.stderr)
            continue

        if host.runtime.powerState != vim.HostSystemPowerState.poweredOn:
            if verbose:
                print(f"Skipping {host.name}: not powered on", file=sys.stderr)
            continue

        # Skip hosts in maintenance mode
        if host.runtime.inMaintenanceMode:
            if verbose:
                print(f"Skipping {host.name}: in maintenance mode", file=sys.stderr)
            continue

        info = get_host_resources(host)
        if info:
            hosts_info.append(info)

    if not hosts_info:
        print("ERROR: No suitable hosts found in cluster", file=sys.stderr)
        sys.exit(1)

    # Select best host based on metric
    if metric == "cpu":
        best_host = max(hosts_info, key=lambda x: x["cpu_available_mhz"])
    elif metric == "memory":
        best_host = max(hosts_info, key=lambda x: x["memory_available_mb"])
    else:  # balanced
        # Balanced score: average of CPU and memory availability percentages
        for host in hosts_info:
            host["balanced_score"] = (
                host["cpu_available_percent"] + host["memory_available_percent"]
            ) / 2
        best_host = max(hosts_info, key=lambda x: x["balanced_score"])

    if verbose:
        print("\n=== All Hosts ===", file=sys.stderr)
        for host in sorted(hosts_info, key=lambda x: x["name"]):
            print(f"\nHost: {host['name']}", file=sys.stderr)
            print(
                f"  CPU Available: {host['cpu_available_mhz']:.0f} MHz ({host['cpu_available_percent']:.1f}%)",
                file=sys.stderr,
            )
            print(
                f"  Memory Available: {host['memory_available_mb']:.0f} MB ({host['memory_available_percent']:.1f}%)",
                file=sys.stderr,
            )
            print(f"  VMs: {host['num_vms']}", file=sys.stderr)
            if "balanced_score" in host:
                print(
                    f"  Balanced Score: {host['balanced_score']:.1f}%", file=sys.stderr
                )
        print(f"\n=== Selected Best Host: {best_host['name']} ===\n", file=sys.stderr)

    return best_host, hosts_info


def main():
    args = get_args()

    # Connect to vSphere
    si = get_vsphere_connection()

    try:
        # Find cluster
        cluster = find_cluster(si, args.datacenter, args.cluster)

        # Select best host
        best_host, all_hosts = select_best_host(cluster, args.metric, args.verbose)

        # Output result
        if args.format == "json":
            import json

            output = {"selected_host": best_host, "all_hosts": all_hosts}
            print(json.dumps(output, indent=2))
        else:
            # Just print the FQDN for Terraform consumption
            print(best_host["name"])

    finally:
        Disconnect(si)


if __name__ == "__main__":
    main()
