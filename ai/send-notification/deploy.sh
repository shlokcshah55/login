#!/bin/bash

# FCM Push Notification Cloud Function Deployment Script
# This script deploys the send_push_notification function to GCP

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FCM Push Notification Function Deployer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
PROJECT_ID="pinit-a97eb"  
FUNCTION_NAME="send_push_notification"
REGION="us-central1"
RUNTIME="python311"
ENTRY_POINT="send_push_notification"
MEMORY="256MB"
TIMEOUT="60s"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Error: gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
echo -e "${YELLOW}Checking authentication...${NC}"
CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ -z "$CURRENT_ACCOUNT" ]; then
    echo -e "${RED}❌ Not authenticated. Running 'gcloud auth login'...${NC}"
    gcloud auth login
fi
echo -e "${GREEN}✓ Authenticated as: $CURRENT_ACCOUNT${NC}"

# Set project
echo -e "${YELLOW}Setting project to: $PROJECT_ID${NC}"
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✓ Project set${NC}"
echo ""

# Check if API_SECRET_KEY environment variable is set
if [ -z "$API_SECRET_KEY" ]; then
    echo -e "${YELLOW}⚠️  API_SECRET_KEY not found in environment${NC}"
    echo -e "${YELLOW}Generating a new secret key...${NC}"
    API_SECRET_KEY=$(openssl rand -base64 32)
    echo -e "${GREEN}✓ Generated secret key${NC}"
    echo -e "${BLUE}Your API Secret Key:${NC}"
    echo -e "${GREEN}$API_SECRET_KEY${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Save this key! You'll need it for:${NC}"
    echo "   1. Supabase vault (for database triggers)"
    echo "   2. Direct API calls from your app"
    echo ""
    read -p "Press Enter to continue with deployment..."
else
    echo -e "${GREEN}✓ Using API_SECRET_KEY from environment${NC}"
fi
echo ""

# Enable required APIs
echo -e "${YELLOW}Enabling required GCP APIs...${NC}"
gcloud services enable \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    --project=$PROJECT_ID \
    --quiet

echo -e "${GREEN}✓ APIs enabled${NC}"
echo ""

# Grant permissions to default service account
echo -e "${YELLOW}Checking service account permissions...${NC}"
SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"

# Check if service account has Firebase Admin role
HAS_FIREBASE_ROLE=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT AND bindings.role:roles/firebase.sdkAdminServiceAgent" \
    --format="value(bindings.role)" 2>/dev/null || echo "")

if [ -z "$HAS_FIREBASE_ROLE" ]; then
    echo -e "${YELLOW}Adding Firebase Admin role to service account...${NC}"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/firebase.sdkAdminServiceAgent" \
        --quiet
    echo -e "${GREEN}✓ Firebase Admin role granted${NC}"
else
    echo -e "${GREEN}✓ Service account already has Firebase Admin role${NC}"
fi
echo ""

# Check if function source files exist
if [ ! -f "main.py" ]; then
    echo -e "${RED}❌ Error: main.py not found in current directory${NC}"
    echo "Please run this script from the directory containing your function code"
    exit 1
fi

if [ ! -f "requirements.txt" ]; then
    echo -e "${RED}❌ Error: requirements.txt not found in current directory${NC}"
    echo "Please run this script from the directory containing your function code"
    exit 1
fi

echo -e "${GREEN}✓ Function source files found${NC}"
echo ""

# Deploy the function
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deploying Cloud Function...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Configuration:"
echo "  Project:      $PROJECT_ID"
echo "  Function:     $FUNCTION_NAME"
echo "  Region:       $REGION"
echo "  Runtime:      $RUNTIME"
echo "  Memory:       $MEMORY"
echo "  Timeout:      $TIMEOUT"
echo ""

gcloud functions deploy $FUNCTION_NAME \
    --runtime=$RUNTIME \
    --trigger-http \
    --allow-unauthenticated \
    --entry-point=$ENTRY_POINT \
    --project=$PROJECT_ID \
    --region=$REGION \
    --set-env-vars=API_SECRET_KEY="$API_SECRET_KEY" \
    --memory=$MEMORY \
    --timeout=$TIMEOUT \
    --quiet

# Get the function URL
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(httpsTrigger.url)")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Function URL:${NC}"
echo -e "${GREEN}$FUNCTION_URL${NC}"
echo ""
echo -e "${BLUE}API Secret Key:${NC}"
echo -e "${GREEN}$API_SECRET_KEY${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Save the API Secret Key in Supabase Vault:"
echo "   INSERT INTO vault.secrets (name, secret)"
echo "   VALUES ('gcp_notification_api_key', '$API_SECRET_KEY');"
echo ""
echo "2. Test the function with curl:"
echo "   curl -X POST $FUNCTION_URL \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -H 'Authorization: Bearer $API_SECRET_KEY' \\"
echo "     -d '{\"fcm_token\":\"YOUR_TOKEN\",\"title\":\"Test\",\"body\":\"Hello!\"}'"
echo ""
echo -e "${GREEN}Done!${NC}"