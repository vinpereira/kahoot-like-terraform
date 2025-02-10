# Kahoot-like Game Infrastructure

This repository contains the infrastructure as code (Terraform) and backend implementation for a Kahoot-like real-time quiz game application.

## Architecture Overview

The application uses several AWS services:
- **API Gateway**: REST API for questions and WebSocket API for real-time game interactions
- **Lambda**: Serverless functions for game logic and API handlers
- **DynamoDB**: NoSQL database for storing questions, games, connections, and answers
- **SQS**: Message queue for processing game answers
- **S3**: Static website hosting and pipeline artifacts
- **CloudFront**: Content delivery network for the frontend
- **CodePipeline**: CI/CD pipeline for the React frontend

## Project Structure

```
terraform-kahoot/
├── terraform/
│   ├── main.tf              # Main infrastructure configuration
│   ├── variables.tf         # Variable declarations
│   ├── outputs.tf           # Output definitions
│   ├── providers.tf         # Provider configurations
│   ├── terraform.tfvars     # Variable values
│   ├── modules/
│   │   ├── api/            # API Gateway configurations
│   │   ├── compute/        # Lambda functions and IAM roles
│   │   ├── storage/        # S3 and CloudFront
│   │   ├── database/       # DynamoDB tables
│   │   ├── messaging/      # SQS configuration
│   │   └── ci_cd/          # CodePipeline and CodeBuild
│   └── lambdas/
│       ├── getQuestions/
│       │   └── getQuestions.mjs  # REST API Lambda handler
│       ├── handleWebSocket/
│       │   └── handleWebSocket.mjs  # WebSocket Lambda handler
│       └── sqsProcessor/
│           └── sqsProcessor.mjs  # SQS message processor
└── README.md
```

## Prerequisites

1. AWS Account and configured AWS CLI
2. Terraform >= 1.2.0
3. Node.js >= 20.x
4. GitHub repository for the frontend application

## Setup Instructions

### 1. Clone the Repository

```bash
git clone 
cd terraform-kahoot
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Configure Variables

Create a `terraform.tfvars` file with your specific values:

```hcl
aws_region = "us-east-1"
aws_profile = "terraform-admin"
project_name = "kahoot-like"
environment = "dev"
github_repository_frontend = "your-username/your-frontend-repo"
github_branch_frontend = "main"
website_bucket_name = "your-website-bucket-name"
artifacts_bucket_name = "your-artifacts-bucket-name"
lambda_runtime = "nodejs20.x"
```

### 4. Deploy Infrastructure

```bash
terraform plan
terraform apply
```

### 5. Post-Deployment Manual Steps

After successful deployment, several manual steps are required:

1. **Connect GitHub to AWS CodePipeline**:
   - Go to AWS Console > Developer Tools > CodeStar Connections
   - Find the pending connection
   - Click "Update pending connection"
   - Follow the prompts to authorize GitHub access

2. **Update Frontend Configuration**:
   - In your frontend repository, update the `config.js` file with:
     - API URL (from terraform outputs)
     - WebSocket URL (from terraform outputs)
   - Commit and push these changes

3. **Trigger Initial Deployment**:
   - Go to AWS CodePipeline console
   - Find your pipeline
   - Click "Release Change" to trigger the initial deployment

4. **Add Questions to DynamoDB**:
   - Go to AWS DynamoDB console
   - Find the "KahootQuestions" table
   - Add initial questions manually or using AWS CLI

### 6. Verify Deployment

- Check CloudFront distribution is deployed
- Verify frontend is accessible
- Test WebSocket connections
- Confirm questions API is working

## Database Structure

### DynamoDB Tables

1. **KahootQuestions**
   - Partition Key: QuestionID (String)
   - Contains quiz questions and answers

2. **KahootConnections**
   - Partition Key: connectionId (String)
   - Tracks WebSocket connections

3. **KahootGames**
   - Partition Key: gameId (String)
   - GSI: GameCodeIndex (gameCode as partition key)
   - Stores active game sessions

4. **KahootAnswers**
   - Partition Key: gameId_playerId (String)
   - Sort Key: questionId (String)
   - Records player answers

## API Endpoints

### REST API
- GET `/questions` - Retrieve quiz questions

### WebSocket API Routes
- `$connect` - Handle client connection
- `$disconnect` - Handle client disconnection
- `initiateGame` - Create new game session
- `joinGame` - Join existing game
- `startGame` - Begin game session
- `nextQuestion` - Proceed to next question
- `submitAnswer` - Submit answer for current question
- `endGame` - Terminate game session

## Environment Variables

The following environment variables are set in CodeBuild for the frontend deployment:
- `REACT_APP_API_ENDPOINT` - REST API endpoint
- `REACT_APP_WS_ENDPOINT` - WebSocket endpoint
- `WEBSITE_BUCKET` - S3 bucket for website hosting
- `CLOUDFRONT_DISTRIBUTION_ID` - CloudFront distribution ID

## Deployment Environments

- Development: Use `dev.tfvars`
  ```bash
  terraform plan -var-file="dev.tfvars"
  terraform apply -var-file="dev.tfvars"
  ```

- Production: Use `prod.tfvars`
  ```bash
  terraform plan -var-file="prod.tfvars"
  terraform apply -var-file="prod.tfvars"
  ```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy"
```

Note: This will remove all resources including S3 buckets and DynamoDB tables. Make sure to backup any important data before destroying.

## Monitoring and Maintenance

- CloudWatch Logs are enabled for all Lambda functions
- CodeBuild logs are available in CloudWatch
- Pipeline notifications can be configured through SNS

## Security Considerations

1. S3 buckets are configured with private access
2. CloudFront uses OAI for S3 access
3. IAM roles follow principle of least privilege
4. API Gateway endpoints can be secured with authentication if needed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Your chosen license]