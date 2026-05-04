#!/bin/bash
# =============================================================================
# deploy.sh — Full-Stack AWS Deployment for WroclawGO
#
# Phases:
#   0  Prerequisites — verify tooling and AWS credentials
#   1  Terraform init
#   2  Bootstrap ECR — create the backend repository
#   3  Docker build & push — build backend image and push to ECR with a unique tag
#   4  Full terraform apply — creates EC2, RDS, secrets, and S3 website hosting
#   5  Frontend build & deploy — inject backend URL, build Angular, sync S3 website
# =============================================================================

set -euo pipefail
export AWS_PAGER=""
export PAGER=cat

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

tf_state_has() {
  terraform state list | grep -Fxq "$1"
}

ssm_run_and_wait() {
  local instance_id="$1"
  local command_json="$2"

  local cmd_id
  local send_output
  local send_exit

  set +e
  send_output=$(aws ssm send-command \
    --region "$AWS_REGION" \
    --instance-ids "$instance_id" \
    --document-name AWS-RunShellScript \
    --parameters "$command_json" \
    --query 'Command.CommandId' \
    --output text 2>&1)
  send_exit=$?
  set -e

  if [ "$send_exit" -ne 0 ]; then
    echo "$send_output" >&2
    return 1
  fi

  cmd_id="$send_output"
  if [ -z "$cmd_id" ] || [ "$cmd_id" = "None" ] || [ "$cmd_id" = "null" ]; then
    echo "SSM send-command did not return a valid CommandId." >&2
    echo "$send_output" >&2
    return 1
  fi

  aws ssm wait command-executed \
    --region "$AWS_REGION" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id"

  aws ssm get-command-invocation \
    --region "$AWS_REGION" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id" \
    --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
    --output json
}

wait_for_ssm_ready() {
  local instance_id="$1"

  log "Waiting for backend EC2 instance to be running..."
  aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$instance_id"

  log "Waiting for EC2 status checks to pass..."
  aws ec2 wait instance-status-ok --region "$AWS_REGION" --instance-ids "$instance_id"

  log "Waiting for SSM agent to be online..."
  for attempt in $(seq 1 30); do
    ping_status=$(aws ssm describe-instance-information \
      --region "$AWS_REGION" \
      --filters "Key=InstanceIds,Values=$instance_id" \
      --query 'InstanceInformationList[0].PingStatus' \
      --output text 2>/dev/null || true)

    if [ "$ping_status" = "Online" ]; then
      log "SSM agent is online for instance $instance_id."
      return 0
    fi

    if [ "$attempt" -eq 30 ]; then
      fail "SSM agent did not become online for instance $instance_id."
    fi

    sleep 10
  done
}

ensure_rds_ingress_for_backend() {
  local instance_id="$1"

  local backend_sg_id
  backend_sg_id=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

  [ -z "$backend_sg_id" ] && fail "Could not determine backend instance security group for $instance_id"

  local rds_sg_id
  rds_sg_id=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text)

  [ -z "$rds_sg_id" ] && fail "Could not determine RDS security group for $DB_INSTANCE_ID"

  if aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --group-ids "$rds_sg_id" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\`].UserIdGroupPairs[?GroupId=='$backend_sg_id']" \
    --output text | grep -q "$backend_sg_id"; then
    log "RDS ingress already allows backend SG $backend_sg_id on port 5432."
    return 0
  fi

  log "Adding missing RDS ingress from backend SG $backend_sg_id to RDS SG $rds_sg_id on port 5432..."
  aws ec2 authorize-security-group-ingress \
    --region "$AWS_REGION" \
    --group-id "$rds_sg_id" \
    --ip-permissions "[{\"IpProtocol\":\"tcp\",\"FromPort\":5432,\"ToPort\":5432,\"UserIdGroupPairs\":[{\"GroupId\":\"$backend_sg_id\",\"Description\":\"Allow inbound PostgreSQL from backend EC2\"}]}]" \
    >/dev/null
}

cleanup_stale_backends() {
  local managed_instance_id="$1"
  local backend_name_tag="$2"

  mapfile -t all_backend_ids < <(
    aws ec2 describe-instances \
      --region "$AWS_REGION" \
      --filters "Name=tag:Name,Values=${backend_name_tag}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text | tr '\t' '\n' | sed '/^$/d'
  )

  stale_ids=()
  for instance_id in "${all_backend_ids[@]}"; do
    if [ "$instance_id" != "$managed_instance_id" ]; then
      stale_ids+=("$instance_id")
    fi
  done

  if [ "${#stale_ids[@]}" -eq 0 ]; then
    return 0
  fi

  log "Detected stale backend EC2 instances: ${stale_ids[*]}"
  if [ "${CLEANUP_STALE_BACKENDS:-false}" = "true" ]; then
    log "CLEANUP_STALE_BACKENDS=true, terminating stale backend instances."
    aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids "${stale_ids[@]}" >/dev/null
  else
    log "Leaving stale backend instances untouched (set CLEANUP_STALE_BACKENDS=true to auto-terminate)."
  fi
}

import_if_exists() {
  local address="$1"
  local import_id="$2"
  local check_cmd="$3"

  if tf_state_has "$address"; then
    log "$address is already managed in Terraform state."
    return 0
  fi

  if eval "$check_cmd" >/dev/null 2>&1; then
    log "Importing existing resource into state: $address"
    set +e
    import_output=$(terraform import "$address" "$import_id" 2>&1)
    import_exit=$?
    set -e

    if [ "$import_exit" -ne 0 ]; then
      if echo "$import_output" | grep -q "Resource already managed by Terraform"; then
        log "$address is already managed in Terraform state. Skipping import."
      else
        echo "$import_output" >&2
        fail "Failed to import $address"
      fi
    fi
  else
    log "Resource not found in AWS (Terraform will create): $address"
  fi
}

log "=== PHASE 0: Checking prerequisites ==="
for cmd in aws terraform docker npm python3 curl; do
  command -v "$cmd" &>/dev/null || fail "$cmd is not installed. Please install it first."
done
log "All required tools found."

log "Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
  log "Not logged into AWS. Please provide your credentials."
  aws configure
  aws sts get-caller-identity &>/dev/null || fail "AWS authentication failed. Exiting."
fi
log "Successfully authenticated with AWS."

AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region || true)}}
[ -z "$AWS_REGION" ] && fail "AWS region is not configured. Set AWS_REGION/AWS_DEFAULT_REGION or run 'aws configure'."

log "RDS access restriction:"
log "  Enter the CIDR that may connect to PostgreSQL port 5432 for maintenance."
log "  Recommended: your current public IP in the form x.x.x.x/32"
log "  Leave blank to use the default '0.0.0.0/0' (open — only for demos)."
ADMIN_CIDR_RAW="${ADMIN_CIDR:-0.0.0.0/0}"
ADMIN_CIDR=$(python3 -c "import ipaddress; print(str(ipaddress.ip_network('${ADMIN_CIDR_RAW}', strict=False)))" 2>/dev/null) \
  || fail "'${ADMIN_CIDR_RAW}' is not a valid IPv4 CIDR (e.g. 1.2.3.4/32)"
log "Using admin_cidr: $ADMIN_CIDR"

log "=== PHASE 1: Initialising Terraform ==="
cd terraform
terraform init -upgrade
log "Terraform initialised."

PROJECT_NAME="${TF_VAR_project_name:-wroclawgo}"
ENVIRONMENT="${TF_VAR_environment:-prod}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

FRONTEND_BUCKET_NAME="${PROJECT_NAME}-frontend-${ENVIRONMENT}"
LOG_BUCKET_NAME="${FRONTEND_BUCKET_NAME}-logs"
MEDIA_BUCKET_NAME="${PROJECT_NAME}-media-${ENVIRONMENT}"
DB_SECRET_NAME="${PROJECT_NAME}-db-password"
DJANGO_SECRET_NAME="${PROJECT_NAME}-django-secret-key"
BACKEND_ROLE_NAME="${PROJECT_NAME}-backend-ec2-role"
BACKEND_POLICY_NAME="${PROJECT_NAME}-backend-runtime-policy"
BACKEND_POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${BACKEND_POLICY_NAME}"
BACKEND_INSTANCE_PROFILE_NAME="${PROJECT_NAME}-backend-instance-profile"
ECR_REPO_NAME="${ECR_REPO_NAME:-${PROJECT_NAME}-backend}"
DB_INSTANCE_ID="${PROJECT_NAME}-postgres"

log "=== PHASE 1.5: Importing existing infrastructure into Terraform state ==="
import_if_exists "aws_ecr_repository.backend" "$ECR_REPO_NAME" \
  "aws ecr describe-repositories --region '$AWS_REGION' --repository-names '$ECR_REPO_NAME'"

import_if_exists "aws_iam_role.backend_instance_role" "$BACKEND_ROLE_NAME" \
  "aws iam get-role --role-name '$BACKEND_ROLE_NAME'"

import_if_exists "aws_iam_policy.backend_runtime_policy" "$BACKEND_POLICY_ARN" \
  "aws iam get-policy --policy-arn '$BACKEND_POLICY_ARN'"

import_if_exists "aws_iam_instance_profile.backend" "$BACKEND_INSTANCE_PROFILE_NAME" \
  "aws iam get-instance-profile --instance-profile-name '$BACKEND_INSTANCE_PROFILE_NAME'"

import_if_exists "aws_secretsmanager_secret.db_password" "$DB_SECRET_NAME" \
  "aws secretsmanager describe-secret --region '$AWS_REGION' --secret-id '$DB_SECRET_NAME'"

import_if_exists "aws_secretsmanager_secret.django_secret_key" "$DJANGO_SECRET_NAME" \
  "aws secretsmanager describe-secret --region '$AWS_REGION' --secret-id '$DJANGO_SECRET_NAME'"

import_if_exists "aws_s3_bucket.media" "$MEDIA_BUCKET_NAME" \
  "aws s3api head-bucket --bucket '$MEDIA_BUCKET_NAME'"

import_if_exists "module.s3.aws_s3_bucket.frontend_bucket" "$FRONTEND_BUCKET_NAME" \
  "aws s3api head-bucket --bucket '$FRONTEND_BUCKET_NAME'"

import_if_exists "module.s3.aws_s3_bucket.log_bucket" "$LOG_BUCKET_NAME" \
  "aws s3api head-bucket --bucket '$LOG_BUCKET_NAME'"

import_if_exists "module.db.module.db_instance.aws_db_instance.this[0]" "$DB_INSTANCE_ID" \
  "aws rds describe-db-instances --region '$AWS_REGION' --db-instance-identifier '$DB_INSTANCE_ID'"

log "Terraform state import bootstrap finished."

log "=== PHASE 2: Creating ECR repository ==="
terraform apply -auto-approve \
  -var "admin_cidr=${ADMIN_CIDR}" \
  -target=aws_ecr_repository.backend
log "ECR repository is ready."

log "=== PHASE 3: Building and pushing backend Docker image ==="
ECR_REPO_URL=$(terraform output -raw ecr_repo_url)
IMAGE_TAG=$(date +%Y%m%d%H%M%S)

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO_URL"

cd ..
docker build -t wroclawgo-backend ./back
docker tag wroclawgo-backend:latest "$ECR_REPO_URL:$IMAGE_TAG"
docker push "$ECR_REPO_URL:$IMAGE_TAG"
docker tag wroclawgo-backend:latest "$ECR_REPO_URL:latest"
docker push "$ECR_REPO_URL:latest"
cd terraform

log "=== PHASE 4: Full infrastructure apply ==="
terraform apply -auto-approve \
  -var "admin_cidr=${ADMIN_CIDR}"

S3_BUCKET=$(terraform output -raw s3_bucket_name)
WEBSITE_URL=$(terraform output -raw website_url)
BACKEND_URL=$(terraform output -raw backend_url)

[ -z "$S3_BUCKET" ] && fail "Could not read s3_bucket_name from Terraform outputs."
[ -z "$BACKEND_URL" ] && fail "Could not read backend_url from Terraform outputs."

BACKEND_INSTANCE_ID=$(terraform output -raw backend_instance_id)
[ -z "$BACKEND_INSTANCE_ID" ] && fail "Could not read backend_instance_id from Terraform outputs."

cleanup_stale_backends "$BACKEND_INSTANCE_ID" "${PROJECT_NAME}-backend"

wait_for_ssm_ready "$BACKEND_INSTANCE_ID"
ensure_rds_ingress_for_backend "$BACKEND_INSTANCE_ID"

log "Updating backend container on managed EC2 via SSM..."
if ! UPDATE_RESULT=$(ssm_run_and_wait "$BACKEND_INSTANCE_ID" "{\"commands\":[\"set -e\",\"aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}\",\"docker pull ${ECR_REPO_URL}:latest\",\"docker rm -f wroclawgo-backend || true\",\"docker run -d --name wroclawgo-backend --restart unless-stopped --env-file /opt/wroclawgo/backend.env -p 80:8000 ${ECR_REPO_URL}:latest\"]}"); then
  fail "Failed to update backend container via SSM."
fi
echo "$UPDATE_RESULT"

log "Waiting for backend to start on EC2..."
for attempt in $(seq 1 30); do
  STATUS=$(curl -m 5 -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/admin/login/" || true)
  log "  Attempt ${attempt}/30 -> HTTP ${STATUS} at ${BACKEND_URL}/admin/login/"
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
    log "Backend responded with HTTP $STATUS."
    break
  fi

  if [ "$attempt" -eq 30 ]; then
    log "Backend did not respond in time. Collecting diagnostics from EC2 via SSM..."
    DIAG_RESULT=$(ssm_run_and_wait "$BACKEND_INSTANCE_ID" '{"commands":["docker ps -a","echo ---","docker logs --tail 120 wroclawgo-backend || true"]}')
    echo "$DIAG_RESULT"
    fail "Backend did not become ready in time. See SSM diagnostics above for container errors."
  fi

  sleep 10
done

log "Running database seed on EC2 backend..."
SEED_COMMAND_ID=$(aws ssm send-command \
  --region "$AWS_REGION" \
  --instance-ids "$BACKEND_INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --parameters '{"commands":["docker exec wroclawgo-backend python seed_wroclaw.py"]}' \
  --query 'Command.CommandId' \
  --output text)

for attempt in $(seq 1 24); do
  SEED_STATUS=$(aws ssm get-command-invocation \
    --region "$AWS_REGION" \
    --command-id "$SEED_COMMAND_ID" \
    --instance-id "$BACKEND_INSTANCE_ID" \
    --query 'Status' \
    --output text)

  if [ "$SEED_STATUS" = "Success" ]; then
    log "Seed completed successfully."
    break
  fi

  if [ "$SEED_STATUS" = "Failed" ] || [ "$SEED_STATUS" = "Cancelled" ] || [ "$SEED_STATUS" = "TimedOut" ]; then
    aws ssm get-command-invocation \
      --region "$AWS_REGION" \
      --command-id "$SEED_COMMAND_ID" \
      --instance-id "$BACKEND_INSTANCE_ID" \
      --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
      --output json
    fail "Database seed failed on the EC2 instance."
  fi

  if [ "$attempt" -eq 24 ]; then
    aws ssm get-command-invocation \
      --region "$AWS_REGION" \
      --command-id "$SEED_COMMAND_ID" \
      --instance-id "$BACKEND_INSTANCE_ID" \
      --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
      --output json
    fail "Database seed did not finish in time."
  fi

  sleep 5
done

cd ..

log "=== PHASE 5: Building and deploying Angular frontend ==="
API_CONFIG_FILE="frontend/src/app/config/api.config.ts"

cp "$API_CONFIG_FILE" "${API_CONFIG_FILE}.bak"
cleanup() {
  if [ -f "${API_CONFIG_FILE}.bak" ]; then
    mv "${API_CONFIG_FILE}.bak" "$API_CONFIG_FILE"
    log "api.config.ts restored to local default state."
  fi
}
trap cleanup EXIT

sed -i "s|http://localhost:8000|${BACKEND_URL}|g" "$API_CONFIG_FILE"

cd frontend
npm ci
npm run build -- --configuration=production
cd ..

BUILD_DIR="frontend/dist/frontend/browser"
[ ! -d "$BUILD_DIR" ] && fail "Build directory ($BUILD_DIR) not found. Build may have failed."

aws s3 sync "$BUILD_DIR" "s3://$S3_BUCKET" \
  --delete \
  --sse AES256 \
  --exclude "index.html" \
  --cache-control "public, max-age=31536000, immutable"

aws s3 cp "$BUILD_DIR/index.html" "s3://$S3_BUCKET/index.html" \
  --sse AES256 \
  --cache-control "no-cache, no-store, must-revalidate" \
  --content-type "text/html"

log "=== PHASE 6: Updating Flutter mobile backend URL ==="
MOBILE_CONFIG_FILE="mobile/lib/core/config/app_config.dart"

if [ -f "$MOBILE_CONFIG_FILE" ]; then
  sed -i -E "s|defaultValue: 'http://[^']+'|defaultValue: '${BACKEND_URL}'|g" "$MOBILE_CONFIG_FILE"
  log "Flutter mobile backend URL updated in $MOBILE_CONFIG_FILE"
else
  log "Flutter mobile config file not found, skipping mobile backend URL update."
fi

log "=== Deployment Complete! ==="
log "Frontend : $WEBSITE_URL"
log "Backend  : $BACKEND_URL"
