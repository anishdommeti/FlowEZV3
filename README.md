# FlowEZ

### Smart Real-Time Queue Management System

FlowEZ is a digital queue management system designed to reduce the need for people to physically wait in queues.

Users can join queues remotely or by scanning a QR code, receive a unique token, and track their position and estimated waiting time in real time. Administrators can create and manage queues, call the next token, and monitor queue activity from the admin interface.

## Features

### User
- Join queues remotely or through QR codes
- Receive a unique queue token
- Track current position in the queue
- View estimated waiting time
- Receive real-time queue updates

### Admin
- Create and manage service queues
- Define expected service time
- Generate unique QR codes for queues
- Call the next token
- Monitor active queues
- View queue analytics
- Reset or close queues

## Tech Stack

- **Frontend:** Flutter & Dart
- **State Management:** Provider
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **QR Code:** QR-based queue joining
- **Architecture:** Service-based architecture with real-time Firestore streams

## How It Works

1. An administrator creates a queue and defines the expected service time.
2. FlowEZ generates a unique QR code for the queue.
3. Users can find the queue directly or scan the QR code.
4. A unique token is generated and stored in Firestore.
5. Queue changes are synchronized using Firestore real-time streams.
6. When the administrator calls the next token, connected users receive the updated queue state automatically.

## Reliability

FlowEZ uses Firestore transactions for token allocation. This ensures that concurrent users joining a queue do not receive duplicate token numbers.

The application was also tested and debugged through multiple runtime and configuration issues during development.

## AI Usage

AI was used during development primarily as an engineering assistant for debugging, understanding unfamiliar errors, and exploring possible solutions.

AI-based waiting-time prediction was considered as a future feature. It is not currently implemented because the system does not yet have enough real historical queue data to justify a reliable prediction model.

## Future Scope

- AI-based waiting-time prediction
- Improved queue analytics
- Additional notification capabilities
- Further optimization based on real-world queue data

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Firebase project

### Installation

Clone the repository:

```bash
git clone <repository-url>
cd flowez_new
