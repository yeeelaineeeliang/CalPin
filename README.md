# CalPin📍 - UC Berkeley Student Support Network

Fostering student support networks at UC Berkeley
A location-based iOS app connecting Berkeley students who need help with nearby helpers. Submit requests, browse by urgency or recency, and build community through mutual aid.

## Development Setup

Backend
npm install
#Configure .env with DATABASE_URL, GOOGLE_CLIENT_ID, ANTHROPIC_API_KEY
npm start


## Architecture

Request lifecycle: Open → In Progress → Completed/Cancelled
Location services: MapKit with custom pin annotations
State management: Shared observer pattern for data consistency
AI integration: Automatic categorization + content safety checks