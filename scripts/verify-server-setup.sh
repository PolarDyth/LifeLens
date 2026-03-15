#!/bin/bash
# Verification script for LifeLens server setup
# Run this on your home server after cloning the repository

set -e

echo "LifeLens Server Setup Verification"
echo "=================================="
echo ""

# Check Docker
echo "1. Checking Docker installation..."
if command -v docker &> /dev/null; then
    echo "   ✓ Docker installed: $(docker --version)"
else
    echo "   ✗ Docker not found. Please install Docker first."
    exit 1
fi

# Check Docker Compose
echo ""
echo "2. Checking Docker Compose installation..."
if command -v docker-compose &> /dev/null; then
    echo "   ✓ Docker Compose installed: $(docker-compose --version)"
else
    echo "   ✗ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

# Check ports
echo ""
echo "3. Checking port availability..."
if netstat -tuln 2>/dev/null | grep -q ":5432 "; then
    echo "   ⚠ Port 5432 already in use (TimescaleDB)"
fi
if netstat -tuln 2>/dev/null | grep -q ":8000 "; then
    echo "   ⚠ Port 8000 already in use (API)"
else
    echo "   ✓ Ports 5432 and 8000 are available"
fi

# Start services
echo ""
echo "4. Starting Docker Compose services..."
cd server
docker-compose up -d

# Wait for services to be healthy
echo ""
echo "5. Waiting for services to be healthy..."
sleep 10

# Check health endpoint
echo ""
echo "6. Testing health endpoint..."
HEALTH=$(curl -s http://localhost:8000/health)
if [[ $HEALTH == *"ok"* ]]; then
    echo "   ✓ Health check passed: $HEALTH"
else
    echo "   ✗ Health check failed"
    docker-compose logs server
    exit 1
fi

# Check TimescaleDB extension
echo ""
echo "7. Verifying TimescaleDB extension..."
TIMESCALEDB=$(docker-compose exec -T db psql -U lifelens -d lifelens -t -c "SELECT extname FROM pg_extension WHERE extname = 'timescaledb';")
if [[ $TIMESCALEDB == *"timescaledb"* ]]; then
    echo "   ✓ TimescaleDB extension enabled"
else
    echo "   ✗ TimescaleDB extension not found"
    exit 1
fi

echo ""
echo "=================================="
echo "✓ All checks passed!"
echo ""
echo "Server is running at: http://localhost:8000"
echo "View logs: docker-compose logs -f"
echo "Stop server: docker-compose down"
