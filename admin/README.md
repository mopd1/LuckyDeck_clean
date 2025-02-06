# LuckyDeck Admin Interface

This directory contains the admin interface for LuckyDeck Gaming, including both the frontend React application and the admin API.

## Directory Structure

```
admin/
├── api/                    # Admin API
│   ├── src/
│   │   ├── config/        # Environment and app configuration
│   │   ├── controllers/   # Request handlers
│   │   ├── middleware/    # Auth and validation middleware
│   │   ├── routes/       # API route definitions
│   │   ├── utils/        # Shared utilities
│   │   └── app.js        # Main application entry
│   ├── migrations/       # Database migrations
│   └── scripts/         # Utility scripts
│
└── frontend/            # Admin Frontend (React)
    ├── src/
    │   ├── components/  # React components
    │   ├── api/        # API integration
    │   ├── hooks/      # Custom React hooks
    │   ├── routes/     # Route definitions
    │   └── utils/      # Utility functions
    └── public/         # Static assets
```

## Setup Instructions

1. Copy `.env.example` to `.env` and configure your environment variables
2. Install dependencies:
   ```bash
   # Install API dependencies
   cd api
   npm install

   # Install frontend dependencies
   cd ../frontend
   npm install
   ```

3. Start the development servers:
   ```bash
   # Start API server
   cd api
   npm run dev

   # Start frontend
   cd ../frontend
   npm run dev
   ```

## Available Scripts

### API
- `npm run dev`: Start development server
- `npm run start`: Start production server
- `npm run migrate`: Run database migrations
- `npm run test`: Run tests

### Frontend
- `npm run dev`: Start development server
- `npm run build`: Build for production
- `npm run preview`: Preview production build
- `npm run test`: Run tests

## Contributing

1. Create a new branch for your feature
2. Make your changes
3. Submit a pull request

## Security

- Never commit sensitive information (API keys, passwords, etc.)
- Always use environment variables for configuration
- Follow security best practices
