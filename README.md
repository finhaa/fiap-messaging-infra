# Messaging Infrastructure

AWS EventBridge + SQS infrastructure for FIAP Tech Challenge Phase 4 microservices communication.

## Overview

This repository provisions the messaging infrastructure that enables asynchronous event-driven communication between microservices:

- **EventBridge Custom Event Bus**: Central event routing hub
- **SQS Queues**: One queue per microservice for event consumption
- **Dead Letter Queues (DLQs)**: Capture failed messages for troubleshooting
- **Event Rules**: Route events to appropriate queues based on event type

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Event Flow Architecture                       │
└─────────────────────────────────────────────────────────────────┘

Producer Service (OS/Billing/Execution)
  │
  ├─ Publish event to EventBridge
  │  └─ Event: { source: "service-name", detail-type: "EventType" }
  │
  ▼
EventBridge Custom Event Bus (fiap-tech-challenge-events)
  │
  ├─ Apply routing rules (match detail-type)
  │
  ├─────┬─────────┬─────────┐
  │     │         │         │
  ▼     ▼         ▼         ▼
SQS   SQS       SQS    Step Functions
(OS)  (Billing) (Exec)
  │     │         │
  ▼     ▼         ▼
Consumer Services (poll SQS)
```

## Resources Provisioned

### EventBridge

- **Event Bus**: `fiap-tech-challenge-events-{env}`
- **Event Archive**: Optional event replay capability
- **Event Rules**: Route events to SQS queues

### SQS Queues

| Queue Name | Purpose | DLQ | Max Retries |
|------------|---------|-----|-------------|
| `os-service-events-{env}` | OS Service event consumption | `os-service-events-dlq-{env}` | 3 |
| `billing-service-events-{env}` | Billing Service event consumption | `billing-service-events-dlq-{env}` | 3 |
| `execution-service-events-{env}` | Execution Service event consumption | `execution-service-events-dlq-{env}` | 3 |

### Event Routing Rules

| Rule Name | Event Pattern | Target |
|-----------|---------------|--------|
| `route-to-os-service` | `detail-type: ["BudgetGenerated", "PaymentCompleted", "ExecutionCompleted"]` | os-service-events queue |
| `route-to-billing-service` | `detail-type: ["OrderCreated", "ExecutionCompleted"]` | billing-service-events queue |
| `route-to-execution-service` | `detail-type: ["PaymentCompleted"]` | execution-service-events queue |

## Prerequisites

- AWS CLI configured
- Terraform >= 1.5
- AWS account with permissions for:
  - EventBridge
  - SQS
  - IAM

## Deployment

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Plan and Apply

```bash
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
# Check EventBridge bus
aws events list-event-buses --query "EventBuses[?Name=='fiap-tech-challenge-events-dev']"

# Check SQS queues
aws sqs list-queues --queue-name-prefix fiap
```

## Usage

### Publishing Events (from microservices)

```typescript
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge';

const client = new EventBridgeClient({ region: 'us-east-1' });

await client.send(new PutEventsCommand({
  Entries: [{
    Source: 'os-service',
    DetailType: 'OrderCreated',
    Detail: JSON.stringify({
      eventId: 'evt_123',
      orderId: 'ord_456',
      clientId: 'cli_789'
    }),
    EventBusName: 'fiap-tech-challenge-events-dev'
  }]
}));
```

### Consuming Events (from microservices)

```typescript
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';

const client = new SQSClient({ region: 'us-east-1' });
const queueUrl = 'https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/os-service-events-dev';

// Long polling (20 seconds)
const { Messages } = await client.send(new ReceiveMessageCommand({
  QueueUrl: queueUrl,
  MaxNumberOfMessages: 10,
  WaitTimeSeconds: 20
}));

for (const message of Messages || []) {
  const event = JSON.parse(message.Body);

  // Process event
  await handleEvent(event);

  // Delete message after successful processing
  await client.send(new DeleteMessageCommand({
    QueueUrl: queueUrl,
    ReceiptHandle: message.ReceiptHandle
  }));
}
```

## Monitoring

### CloudWatch Metrics

- `NumberOfMessagesSent` - Messages published to queues
- `NumberOfMessagesReceived` - Messages consumed from queues
- `ApproximateAgeOfOldestMessage` - Message backlog indicator
- `ApproximateNumberOfMessagesVisible` - Queue depth

### CloudWatch Alarms

Alarms are created for:
- Queue depth > 1000 messages (backlog alert)
- DLQ has messages (failed processing alert)
- Old messages > 5 minutes (slow processing alert)

## Troubleshooting

### Messages in DLQ

```bash
# Check DLQ for failed messages
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/os-service-events-dlq-dev \
  --max-number-of-messages 10
```

### Event Archive Replay

```bash
# Replay events from archive (if enabled)
aws events start-replay \
  --replay-name replay-$(date +%s) \
  --event-source-arn arn:aws:events:us-east-1:ACCOUNT_ID:event-bus/fiap-tech-challenge-events-dev \
  --event-start-time 2026-02-10T00:00:00Z \
  --event-end-time 2026-02-10T23:59:59Z \
  --destination ...
```

## Cost Estimation

| Resource | Monthly Cost (estimate) |
|----------|-------------------------|
| EventBridge | $1 per 1M events (free tier: 14M/month) → ~$0 |
| SQS Standard Queues | $0.40 per 1M requests (free tier: 1M/month) → ~$0 |
| **Total** | **~$0** (within free tier for typical usage) |

## Outputs

After successful deployment, Terraform outputs:

```hcl
event_bus_name = "fiap-tech-challenge-events-dev"
event_bus_arn = "arn:aws:events:us-east-1:123456789012:event-bus/fiap-tech-challenge-events-dev"
os_service_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/os-service-events-dev"
billing_service_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/billing-service-events-dev"
execution_service_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/execution-service-events-dev"
```

## Repository Structure

```
messaging-infra/
├── terraform/
│   ├── main.tf                  # Provider, backend, data sources
│   ├── eventbridge.tf           # EventBridge bus, rules, archives
│   ├── sqs.tf                   # SQS queues and DLQs
│   ├── iam.tf                   # IAM roles and policies
│   ├── monitoring.tf            # CloudWatch alarms
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── terraform.tfvars         # Variable values (git-ignored)
│   └── terraform.tfvars.example # Example variable values
├── scripts/
│   └── test-event-publish.sh    # Test script to publish sample event
├── .github/
│   └── workflows/
│       └── terraform.yml        # CI/CD pipeline
├── .gitignore
├── README.md
└── CLAUDE.md                    # Claude Code guidance
```

## CI/CD Pipeline

GitHub Actions workflow automatically:
1. Validates Terraform configuration
2. Runs `terraform plan` on PRs
3. Applies changes on merge to main

## Related Repositories

- [os-service](../os-service) - Service Order microservice
- [billing-service](../billing-service) - Billing & Payment microservice
- [execution-service](../execution-service) - Execution management microservice

## License

FIAP Tech Challenge - Phase 4

## Authors

- Your Team Names Here
