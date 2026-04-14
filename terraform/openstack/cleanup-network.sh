#!/usr/bin/env bash
# Delete the pre-existing network topology so Terraform can recreate it cleanly.
# Run this before `terraform apply` when redeploying into a project that already
# has a network/router from a previous deployment.
#
# Requires: openstack CLI

set -euo pipefail

read -rp "This will delete group-project-router, group-project-network-subnet, and group-project-network. Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

openstack router remove subnet group-project-router group-project-network-subnet
openstack router delete group-project-router
openstack subnet delete group-project-network-subnet
openstack network delete group-project-network

echo "Done. Run: terraform apply"
