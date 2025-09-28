#!/bin/bash
# Script to start development environment with Docker Compose

echo "🐳 Starting development environment..."

# Start all services
docker compose -f docker/docker-compose.yml up -d

echo "✅ Development environment started!"
echo "📊 Service status:"

docker compose -f docker/docker-compose.yml ps

echo ""
echo "🔗 Connection strings:"
echo "SQL Server: Server=localhost,1433;Database=InsightLearn;User Id=sa;Password=InsightLearn@2024;TrustServerCertificate=true;"
echo "MongoDB: mongodb://admin:InsightLearn@2024@localhost:27017"
echo "Redis: localhost:6379 (password: InsightLearn@2024)"
echo "Elasticsearch: http://localhost:9200"
echo "Ollama: http://localhost:11434"
