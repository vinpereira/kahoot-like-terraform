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
│   ├── dev.tfvars          # Development environment variables
│   └── prod.tfvars         # Production environment variables
├── lambdas/
│   ├── getQuestions/
│   │   └── getQuestions.mjs # REST API Lambda handler
│   ├── webSocket/
│   │   └── handleWebSocket.mjs # WebSocket Lambda handler
│   └── sqsProcessor/
│       └── sqsProcessor.mjs # SQS message processor
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
git clone <repository-url>
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
project_name = "kahoot-like"
environment = "dev"
github_repository_frontend = "your-username/your-frontend-repo"
website_bucket_name = "your-website-bucket-name"
artifacts_bucket_name = "your-artifacts-bucket-name"
```

### 4. Package Lambda Functions

Before applying Terraform, package the Lambda functions:

```bash
cd ../lambdas/getQuestions
zip -r get_questions.zip .

cd ../webSocket
zip -r websocket_handler.zip .

cd ../sqsProcessor
zip -r sqs_processor.zip .
```

### 5. Deploy Infrastructure

```bash
cd ../../terraform
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### 6. Complete GitHub Connection

After deployment:
1. Go to AWS Console > Developer Tools > CodeStar Connections
2. Find the pending connection
3. Click "Update pending connection"
4. Follow the prompts to authorize GitHub access

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
terraform destroy -var-file="dev.tfvars"
```

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