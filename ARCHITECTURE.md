## Terraform AWS Foundation – Architecture & Module Relationships

This project uses Terraform to provision a small but realistic AWS foundation:

- A **VPC with public subnet and internet access**
- A **security group** that controls inbound/outbound network traffic
- A **TLS key pair** for SSH access to the EC2 instance
- An **EC2 instance** running inside the VPC
- A **remote backend in S3** for Terraform state (with optional DynamoDB locking)

All of this is wired together using Terraform **modules** from the root configuration.

---

## High-Level Flow

1. **Terraform reads configuration** from the root files (`backend.tf`, `main.tf`, `variables.tf`, `outputs.tf`).
2. **Backend is configured** using `backend.tf` so state is stored remotely in S3 (and can be locked).
3. **Provider and variables are loaded** from `main.tf` and `variables.tf`.
4. The root `main.tf` **calls child modules** in this order:
   - `vpc` → creates networking
   - `security` → creates a security group in that VPC
   - `keypair` → creates an SSH key pair and writes the private key locally
   - `ec2` → launches an EC2 instance using the subnet, security group, and key pair
5. Root `outputs.tf` **exposes key information** like the EC2 public IP and VPC ID.

You interact with the project only from the **root** (run `terraform init/plan/apply/destroy` there), and Terraform then orchestrates all modules.

---

## Root Files and Their Roles

- **`backend.tf`**
  - Configures the **remote backend**:
    - S3 bucket name, key, region
    - `use_lockfile = true` for safe state operations
  - This must point to an existing S3 bucket in your AWS account.

- **`main.tf`**
  - Declares the **AWS provider** (region, default tags).
  - Specifies **required providers** and versions.
  - Wires the **child modules** together:
    - Calls `module "vpc"` and passes `availability_zone`.
    - Calls `module "security"` and passes `vpc_id` and `my_ip`.
    - Calls `module "keypair"` with a fixed key name and local PEM file path.
    - Calls `module "ec2"` and passes:
      - `ami_id` from root variables
      - `subnet_id` from `module.vpc.public_subnet_id`
      - `security_group_ids` from `module.security.security_group_id`
      - `key_name` from `module.keypair.key_name`

- **`variables.tf`**
  - Defines **inputs to the entire project**:
    - `aws_region`, `availability_zone`
    - `ami_id` for the EC2 instance
    - `key_name` (optional existing key) and `my_ip` (for SSH access)
  - Includes validation for `my_ip` so it must be valid CIDR (for example `1.2.3.4/32`).

- **`outputs.tf`**
  - Exposes key values from modules:
    - `ec2_public_ip` from `module.ec2.public_ip`
    - `vpc_id` from `module.vpc.vpc_id`
  - These outputs are useful for connecting to the instance or integrating with other systems.

- **`README.md`**
  - Human-friendly overview of the project, goals, screenshots, and workflows.

- **`ARCHITECTURE.md` (this file)**
  - More detailed explanation of **how the configuration is structured** and how modules relate to each other.

---

## Modules and How They Connect

All modules live under the `modules/` directory and are only called from the **root `main.tf`**. Modules do not call each other directly; instead, the root passes outputs from one module into another.

### 1. `modules/vpc`

**Purpose:** Create the foundational networking layer.

- **Files**
  - `main.tf`
    - Creates:
      - `aws_vpc.this`
      - `aws_subnet.public`
      - `aws_internet_gateway.igw`
      - `aws_route_table.public_rt` and `aws_route_table_association.public_assoc`
    - Enables DNS support and hostnames on the VPC.
  - `variables.tf`
    - Inputs:
      - `vpc_cidr` – CIDR for the VPC (with validation).
      - `public_subnet_cidr` – CIDR for the public subnet (with validation).
      - `availability_zone` – AZ for the subnet.
      - `vpc_name` – Name tag base.
  - `outputs.tf`
    - `vpc_id` – passed to the `security` module from the root.
    - `public_subnet_id` – passed to the `ec2` module from the root.

**Connections:**

- Root `main.tf` calls `module "vpc"`.
- Root passes `module.vpc.vpc_id` into `module "security"`.
- Root passes `module.vpc.public_subnet_id` into `module "ec2"`.

---

### 2. `modules/security`

**Purpose:** Create a security group that controls network access to the EC2 instance.

- **Files**
  - `main.tf`
    - Creates `aws_security_group.web_sg` with:
      - Ingress rule for SSH (22) from `my_ip`.
      - Ingress rule for HTTP (80) from `0.0.0.0/0`.
      - Egress rule allowing all outbound traffic.
  - `variables.tf`
    - Inputs:
      - `vpc_id` – the VPC in which to create the SG (from the VPC module).
      - `my_ip` – your public IP in CIDR (validated).
      - `security_group_name` – name tag for the SG.
  - `outputs.tf`
    - `security_group_id` – passed to the `ec2` module from the root.

**Connections:**

- Root passes `module.vpc.vpc_id` into `module "security"`.
- Root passes `module.security.security_group_id` into `module "ec2"` as part of `security_group_ids`.

---

### 3. `modules/keypair`

**Purpose:** Generate an SSH key pair and register it in AWS.

- **Files**
  - `main.tf`
    - Creates:
      - `tls_private_key.this` – generates a 4096‑bit RSA key pair.
      - `aws_key_pair.this` – uploads the public key to AWS.
      - `local_file.private_key` – writes the private key (`.pem`) to disk.
  - `variables.tf`
    - Inputs:
      - `key_name` – name of the key pair in AWS.
      - `private_key_path` – where to save the private key locally.
  - `outputs.tf`
    - `key_name` – fed into the EC2 module from the root.
    - `private_key_path` – informational, for you to know where the key was saved.

**Connections:**

- Root `main.tf` calls `module "keypair"` with:
  - `key_name` set to a fixed string (e.g. `project-iac-with-terraform-keypair`).
  - `private_key_path` set to a path under the root module directory.
- Root passes `module.keypair.key_name` into `module "ec2"` as `key_name`.

---

### 4. `modules/ec2`

**Purpose:** Launch the EC2 instance inside the VPC with the correct security group and SSH key.

- **Files**
  - `main.tf`
    - Creates `aws_instance.web` with:
      - AMI (`var.ami_id`).
      - Instance type (`var.instance_type`).
      - Subnet (`var.subnet_id`).
      - Security groups (`var.security_group_ids`).
      - Key pair (`var.key_name`).
      - Tags (including `Name`).
  - `variables.tf`
    - Inputs:
      - `ami_id` – AMI to use.
      - `instance_type` – default `t3.micro`.
      - `subnet_id` – from VPC module.
      - `security_group_ids` – from Security module.
      - `key_name` – from Keypair module.
      - `instance_name` – Name tag for the instance.
  - `outputs.tf`
    - `public_ip` – consumed by root as `ec2_public_ip`.
    - `instance_id` – useful for debugging or further integrations.

**Connections:**

- Root passes:
  - `module.vpc.public_subnet_id` → `module.ec2.subnet_id`.
  - `[module.security.security_group_id]` → `module.ec2.security_group_ids`.
  - `module.keypair.key_name` → `module.ec2.key_name`.
- Root exposes `module.ec2.public_ip` via `outputs.tf`.

---

## How Everything Fits Together

- **Networking first**: The VPC module builds the base network and public subnet.
- **Security next**: The Security module attaches a security group to that VPC.
- **Access credentials**: The Keypair module generates SSH credentials and registers them in AWS.
- **Compute last**: The EC2 module uses:
  - The subnet (from VPC),
  - The security group (from Security),
  - The key pair (from Keypair),
    to start an instance that you can SSH into.
- **State management**: The backend configuration in `backend.tf` ensures Terraform state is stored and locked safely.

The **root module** is the “orchestrator” that knows how all these pieces connect. Each child module is focused on a single responsibility, making the codebase easier to understand, test, and reuse.
