# OJT AI System - Backend API

Node.js/Express backend API for the OJT AI Monitoring System.

## Prerequisites

- Node.js (v14 or higher)
- PostgreSQL (v12 or higher)
- npm or yarn

## Installation

1. Install dependencies:
```bash
npm install
```

2. Create environment file:
Create a `.env` file in `config/env/` directory:

```env
# Database Configuration
DB_USER=postgres
DB_HOST=localhost
DB_NAME=ojt_ai_system
DB_PASSWORD=your_password_here
DB_PORT=5432

# Server Configuration
PORT=3000
NODE_ENV=development

# JWT Secret (use a strong secret in production)
JWT_SECRET=your_jwt_secret_key_here

# API Base URL
API_BASE_URL=http://localhost:3000/api
```

3. Set up the database:
```bash
# Create database
psql -U postgres
CREATE DATABASE ojt_ai_system;

# Run schema
psql -U postgres -d ojt_ai_system -f ../database/schema.sql
```

## Running the Server

### Development Mode (with auto-reload)
```bash
npm run dev
```

### Production Mode
```bash
npm start
```

The server will run on `http://localhost:3000` (or the port specified in `.env`)

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/profile` - Get user profile (requires token)
- `GET /api/auth/users` - Get all users

### Attendance
- `GET /api/attendance` - Get all attendance records
- `POST /api/attendance/time-in` - Record time in
- `PUT /api/attendance/time-out` - Record time out
- `GET /api/attendance/summary` - Get attendance summary
- `PUT /api/attendance/verify/:id` - Verify attendance

### Evaluations
- `GET /api/evaluation` - Get all evaluations
- `POST /api/evaluation` - Create evaluation
- `PUT /api/evaluation/:id` - Update evaluation
- `GET /api/evaluation/:id` - Get evaluation by ID

### Predictions & AI Insights
- `GET /api/prediction/insights` - Get AI insights
- `POST /api/prediction/insights` - Create AI insight
- `GET /api/prediction/performance` - Get performance predictions
- `GET /api/prediction/chatbot/logs` - Get chatbot logs
- `POST /api/prediction/chatbot/logs` - Save chatbot log

### Reports
- `GET /api/reports` - Get all reports
- `POST /api/reports` - Create report
- `GET /api/reports/:id` - Get report by ID
- `GET /api/reports/ojt/records` - Get OJT records
- `POST /api/reports/ojt/records` - Create OJT record

### Health Check
- `GET /api/health` - Check API health status

## Project Structure

```
backend/
├── api/
│   ├── index.js              # Main server file
│   └── routes/
│       ├── auth.js           # Authentication routes
│       ├── attendance.js     # Attendance routes
│       ├── evaluation.js     # Evaluation routes
│       ├── prediction.js     # AI prediction routes
│       └── reports.js        # Report routes
├── config/
│   ├── db.js                 # Database connection
│   └── env/
│       └── .env              # Environment variables
├── controllers/              # Business logic (future)
├── models/                   # Data models (future)
├── middleware/               # Middleware (future)
├── logs/                     # Log files
├── tests/                    # Test files
└── package.json
```

## Database Connection

The backend uses PostgreSQL with the `pg` library. The connection is configured in `config/db.js` and uses environment variables from `.env`.

## Authentication

JWT (JSON Web Tokens) are used for authentication. Tokens are generated on login/registration and should be included in the `Authorization` header:

```
Authorization: Bearer <token>
```

## Error Handling

All errors are returned in the following format:

```json
{
  "error": {
    "message": "Error message",
    "status": 500
  }
}
```

## Testing

```bash
npm test
```

## Production Deployment

1. Set `NODE_ENV=production` in `.env`
2. Use a strong `JWT_SECRET`
3. Configure proper CORS settings
4. Use a process manager like PM2
5. Set up SSL/HTTPS
6. Configure database connection pooling
7. Set up logging and monitoring

## License

ISC

