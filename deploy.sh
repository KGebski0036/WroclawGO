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

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

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

log "RDS access restriction:"
log "  Enter the CIDR that may connect to PostgreSQL port 5432 for maintenance."
log "  Recommended: your current public IP in the form x.x.x.x/32"
log "  Leave blank to use the default '0.0.0.0/0' (open — only for demos)."
read -rp "  admin_cidr [0.0.0.0/0]: " ADMIN_CIDR_INPUT
ADMIN_CIDR_RAW="${ADMIN_CIDR_INPUT:-0.0.0.0/0}"
ADMIN_CIDR=$(python3 -c "import ipaddress; print(str(ipaddress.ip_network('${ADMIN_CIDR_RAW}', strict=False)))" 2>/dev/null) \
  || fail "'${ADMIN_CIDR_RAW}' is not a valid IPv4 CIDR (e.g. 1.2.3.4/32)"
log "Using admin_cidr: $ADMIN_CIDR"

log "=== PHASE 1: Initialising Terraform ==="
cd terraform
terraform init -upgrade
log "Terraform initialised."

log "=== PHASE 2: Creating ECR repository ==="
terraform apply -auto-approve \
  -var "admin_cidr=${ADMIN_CIDR}" \
  -target=aws_ecr_repository.backend
log "ECR repository is ready."

log "=== PHASE 3: Building and pushing backend Docker image ==="
ECR_REPO_URL=$(terraform output -raw ecr_repo_url)
AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region || true)}}
[ -z "$AWS_REGION" ] && fail "AWS region is not configured. Set AWS_REGION/AWS_DEFAULT_REGION or run 'aws configure'."
IMAGE_TAG=$(date +%Y%m%d%H%M%S)

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO_URL"

cd ..
docker build -t wroclawgo-backend ./back
docker tag wroclawgo-backend:latest "$ECR_REPO_URL:$IMAGE_TAG"
docker push "$ECR_REPO_URL:$IMAGE_TAG"
cd terraform

log "=== PHASE 4: Full infrastructure apply ==="
terraform apply -auto-approve \
  -var "admin_cidr=${ADMIN_CIDR}" \
  -var "backend_image_tag=${IMAGE_TAG}"

S3_BUCKET=$(terraform output -raw s3_bucket_name)
WEBSITE_URL=$(terraform output -raw website_url)
BACKEND_URL=$(terraform output -raw backend_url)

[ -z "$S3_BUCKET" ] && fail "Could not read s3_bucket_name from Terraform outputs."
[ -z "$BACKEND_URL" ] && fail "Could not read backend_url from Terraform outputs."

BACKEND_INSTANCE_ID=$(terraform output -raw backend_instance_id)
[ -z "$BACKEND_INSTANCE_ID" ] && fail "Could not read backend_instance_id from Terraform outputs."

log "Waiting for backend to start on EC2..."
for attempt in $(seq 1 30); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/admin/login/" || true)
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
    log "Backend responded with HTTP $STATUS."
    break
  fi

  if [ "$attempt" -eq 30 ]; then
    fail "Backend did not become ready in time. Check the EC2 instance logs in AWS."
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
