# CalPin - UC Berkeley Student Support Network

A mobile app connecting UC Berkeley students who need help with those who can provide assistance.

## Architecture

- **Frontend**: iOS app built with SwiftUI
- **Backend**: Node.js/Express API deployed on Railway
- **Authentication**: Google OAuth with Berkeley email verification

## Development Setup

### Backend
```bash
cd backend
npm install
cp .env.example .env
npm run dev