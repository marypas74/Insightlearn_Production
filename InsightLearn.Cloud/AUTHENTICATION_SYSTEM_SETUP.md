# InsightLearn.Cloud Authentication System Setup Guide

## Overview

This document provides a comprehensive guide to set up and deploy the complete authentication and authorization system for InsightLearn.Cloud. The system includes JWT authentication, OAuth integration (Google/GitHub), role-based access control (RBAC), and a complete user management system.

## Architecture Components

### Backend Services
- **JWT Authentication Service**: Handles login, logout, token generation, and refresh
- **User Management Service**: User CRUD operations, roles, and permissions
- **OAuth Integration Service**: Google and GitHub OAuth login/registration
- **Authorization Service**: Role-based access control and permissions
- **Email Service**: Verification emails, password reset, notifications
- **Audit Service**: Security event logging and tracking

### Database Schema
- **Users**: User accounts with profile information
- **Roles**: User roles (Student, Instructor, Admin)
- **Permissions**: Fine-grained permissions system
- **UserRoles**: Many-to-many relationship between users and roles
- **RolePermissions**: Many-to-many relationship between roles and permissions
- **RefreshTokens**: Secure refresh token storage with rotation
- **OAuthProviders**: External OAuth account linking
- **AuditLogs**: Security and system event logging

### Frontend Components
- **Login/Register Components**: Full authentication UI
- **AuthGuard**: Route protection with role/permission checks
- **AuthStateService**: Client-side authentication state management
- **Dashboard**: User dashboard with profile and activity overview

## Prerequisites

1. **.NET 8 SDK** installed
2. **PostgreSQL** database server
3. **SMTP server** for email notifications
4. **Google OAuth credentials** (optional)
5. **GitHub OAuth credentials** (optional)

## Step 1: Database Setup

### 1.1 Create PostgreSQL Database

```bash
# Create database
createdb insightlearn

# Create user
psql -c "CREATE USER insightlearn WITH ENCRYPTED PASSWORD 'development';"
psql -c "GRANT ALL PRIVILEGES ON DATABASE insightlearn TO insightlearn;"
```

### 1.2 Update Connection String

Update the connection string in `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=insightlearn;Username=insightlearn;Password=your_secure_password;Port=5432"
  }
}
```

## Step 2: Configuration Setup

### 2.1 JWT Configuration

Update JWT settings in `appsettings.json`:

```json
{
  "JwtSettings": {
    "SecretKey": "your-super-secure-256-bit-secret-key-for-production",
    "Issuer": "InsightLearn.Cloud",
    "Audience": "InsightLearn.Cloud.Users",
    "AccessTokenExpirationMinutes": "15",
    "RefreshTokenExpirationDays": "7"
  }
}
```

**Important**: Generate a secure 256-bit key for production:
```bash
openssl rand -base64 32
```

### 2.2 Email Configuration

Configure SMTP settings:

```json
{
  "EmailSettings": {
    "SmtpHost": "smtp.gmail.com",
    "SmtpPort": "587",
    "Username": "your-email@gmail.com",
    "Password": "your-app-password",
    "SenderEmail": "noreply@insightlearn.cloud",
    "SenderName": "InsightLearn.Cloud",
    "UseSsl": "true"
  }
}
```

### 2.3 OAuth Configuration (Optional)

#### Google OAuth Setup:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs:
   - `https://yourdomain.com/auth/callback/google`
   - `http://localhost:5000/auth/callback/google` (development)

```json
{
  "OAuth": {
    "Google": {
      "ClientId": "your-google-client-id",
      "ClientSecret": "your-google-client-secret"
    }
  }
}
```

#### GitHub OAuth Setup:
1. Go to GitHub Settings > Developer settings > OAuth Apps
2. Create a new OAuth App
3. Set Authorization callback URL: `https://yourdomain.com/auth/callback/github`

```json
{
  "OAuth": {
    "GitHub": {
      "ClientId": "your-github-client-id",
      "ClientSecret": "your-github-client-secret"
    }
  }
}
```

## Step 3: Database Migration

Run the Entity Framework migrations to create the database schema:

```bash
cd src/InsightLearn.Api/InsightLearn.Api

# Add migration (if not already created)
dotnet ef migrations add InitialAuthenticationMigration --project ../../InsightLearn.Infrastructure/InsightLearn.Infrastructure

# Update database
dotnet ef database update --project ../../InsightLearn.Infrastructure/InsightLearn.Infrastructure
```

## Step 4: Build and Run

### 4.1 Build the Solution

```bash
cd InsightLearn.Cloud
dotnet build
```

### 4.2 Run the API

```bash
cd src/InsightLearn.Api/InsightLearn.Api
dotnet run
```

The API will be available at:
- HTTP: `http://localhost:5000`
- HTTPS: `https://localhost:5001`
- Swagger UI: `https://localhost:5001/swagger`

### 4.3 Run the Web Application

```bash
cd src/InsightLearn.Web/InsightLearn.Web
dotnet run
```

The web application will be available at:
- HTTP: `http://localhost:5002`
- HTTPS: `https://localhost:5003`

## Step 5: Testing the Authentication System

### 5.1 API Endpoints Testing

Use the Swagger UI at `https://localhost:5001/swagger` to test:

1. **Register a new user**: `POST /api/auth/register`
2. **Login**: `POST /api/auth/login`
3. **Refresh token**: `POST /api/auth/refresh-token`
4. **Get current user**: `GET /api/auth/me`

### 5.2 Web Application Testing

1. Navigate to `https://localhost:5003/register`
2. Create a new account
3. Check email for verification link
4. Login at `https://localhost:5003/login`
5. Access protected dashboard at `https://localhost:5003/dashboard`

## Step 6: Production Deployment

### 6.1 Environment Variables

Set the following environment variables in production:

```bash
# Database
export ConnectionStrings__DefaultConnection="your-production-connection-string"

# JWT
export JwtSettings__SecretKey="your-production-jwt-secret"

# Email
export EmailSettings__Username="your-smtp-username"
export EmailSettings__Password="your-smtp-password"

# OAuth (if using)
export OAuth__Google__ClientId="your-google-client-id"
export OAuth__Google__ClientSecret="your-google-client-secret"
export OAuth__GitHub__ClientId="your-github-client-id"
export OAuth__GitHub__ClientSecret="your-github-client-secret"
```

### 6.2 Docker Deployment

Create a `Dockerfile` for the API:

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/InsightLearn.Api/InsightLearn.Api/InsightLearn.Api.csproj", "src/InsightLearn.Api/InsightLearn.Api/"]
COPY ["src/InsightLearn.Infrastructure/InsightLearn.Infrastructure/InsightLearn.Infrastructure.csproj", "src/InsightLearn.Infrastructure/InsightLearn.Infrastructure/"]
COPY ["src/InsightLearn.Core/InsightLearn.Core/InsightLearn.Core.csproj", "src/InsightLearn.Core/InsightLearn.Core/"]
RUN dotnet restore "src/InsightLearn.Api/InsightLearn.Api/InsightLearn.Api.csproj"
COPY . .
WORKDIR "/src/src/InsightLearn.Api/InsightLearn.Api"
RUN dotnet build "InsightLearn.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "InsightLearn.Api.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "InsightLearn.Api.dll"]
```

### 6.3 Kubernetes Deployment

Create deployment manifests in the `kubernetes/` directory for:
- API deployment and service
- Web application deployment and service
- PostgreSQL database (if not using external)
- ConfigMaps and Secrets for configuration

## Step 7: Security Considerations

### 7.1 Production Security Checklist

- [ ] Use strong, randomly generated JWT secret key
- [ ] Enable HTTPS in production
- [ ] Set secure password requirements
- [ ] Configure proper CORS policies
- [ ] Enable rate limiting
- [ ] Set up monitoring and alerting
- [ ] Regular security audits of audit logs
- [ ] Implement IP whitelisting for admin endpoints

### 7.2 Password Security

The system implements:
- Minimum 8 characters
- Must contain uppercase, lowercase, number, and special character
- BCrypt hashing with work factor 12
- Password history checking (can be extended)

### 7.3 Token Security

- JWT tokens expire in 15 minutes (configurable)
- Refresh tokens expire in 7 days (configurable)
- Refresh token rotation on each use
- Automatic cleanup of expired tokens

## Step 8: Monitoring and Maintenance

### 8.1 Audit Logs

Monitor the following security events:
- Login attempts (successful/failed)
- Password changes/resets
- Role assignments
- Permission changes
- OAuth account linking/unlinking

### 8.2 Background Services

The system includes background services for:
- **Token Cleanup**: Removes expired refresh tokens
- **Audit Log Cleanup**: Archives old audit logs
- **Email Queue Processing**: Handles email sending

### 8.3 Health Checks

Implement health checks for:
- Database connectivity
- Email service availability
- OAuth provider connectivity

## Troubleshooting

### Common Issues

1. **Database Connection Errors**
   - Verify PostgreSQL is running
   - Check connection string
   - Ensure database user has proper permissions

2. **JWT Token Issues**
   - Verify secret key is at least 256 bits
   - Check token expiration times
   - Ensure clock synchronization

3. **Email Not Sending**
   - Verify SMTP credentials
   - Check firewall settings
   - Test SMTP connection manually

4. **OAuth Issues**
   - Verify client IDs and secrets
   - Check redirect URLs
   - Ensure OAuth apps are approved

## API Documentation

The complete API documentation is available at the Swagger UI endpoint when running the application. All authentication endpoints are documented with request/response schemas and example payloads.

## Support

For issues and questions:
1. Check the application logs
2. Review this documentation
3. Check the audit logs for security events
4. Consult the API documentation in Swagger

## Security Updates

Regularly update:
- .NET runtime and packages
- Database server
- Dependencies and NuGet packages
- OAuth application settings
- SSL certificates

This completes the setup and deployment guide for the InsightLearn.Cloud authentication system. The system provides enterprise-grade security with comprehensive user management, audit logging, and scalable architecture.