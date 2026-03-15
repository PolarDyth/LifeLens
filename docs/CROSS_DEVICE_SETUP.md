# Cross-Device Testing Setup

This guide explains how to test the dashboard on your MacBook while the server runs on this Linux machine.

## Network Information

- **Server Machine IP:** `192.168.1.87`
- **Server Port:** `8000`
- **Dashboard Port:** `5173` or `5174`

## Step 1: Update CORS Settings on Server

On the Linux machine (where server runs):

1. Restart the server with updated CORS settings:
   ```bash
   cd /home/williamalexander/Documents/coding/projects/LifeLens/server
   docker compose restart server
   ```

   The server now accepts connections from:
   - `http://localhost:5173`
   - `http://localhost:5174`
   - `http://192.168.1.87:5173`
   - `http://192.168.1.87:5174`

2. Verify the server is accessible:
   ```bash
   curl http://192.168.1.87:8000/health
   ```

   Should return: `{"status":"ok","version":"0.1.0"}`

## Step 2: Clone Repository on MacBook

On your MacBook:

```bash
# Clone the repository (replace with your actual git remote URL)
git clone <your-repo-url> LifeLens
cd LifeLens/dashboard
```

## Step 3: Install Dependencies

```bash
npm install
```

## Step 4: Configure Environment

Create a `.env` file in the `dashboard` directory:

```bash
cat > .env << 'EOF'
# API Configuration - Point to Linux server
VITE_API_URL=http://192.168.1.87:8000
VITE_API_KEY=test-key
VITE_DEVICE_ID=demo-device-macbook
EOF
```

**Important:** Use a different `VITE_DEVICE_ID` on each device to avoid data conflicts.

## Step 5: Start Dashboard

```bash
npm run dev
```

The dashboard should start on `http://localhost:5173` (or another port if 5173 is in use).

## Step 6: Open in Browser

On your MacBook, open: `http://localhost:5173`

You should see:
- ✅ Dashboard with today's metrics
- ✅ Health tab with 7-day charts
- ✅ Productivity tab with app breakdown
- ✅ Location tab with travel data

## Troubleshooting

### "Failed to load data" or "Connection refused"

1. **Check server is running:**
   ```bash
   # On Linux machine
   docker ps | grep lifelens-server
   ```

2. **Check firewall on Linux machine:**
   ```bash
   sudo ufw status
   # If active, allow port 8000:
   sudo ufw allow 8000/tcp
   ```

3. **Test connection from MacBook:**
   ```bash
   curl http://192.168.1.87:8000/health
   ```

### CORS errors in browser console

1. Check browser console for specific CORS error
2. Update `CORS_ORIGINS` in `server/docker-compose.yml` to include your MacBook's IP
3. Restart the server:
   ```bash
   cd /home/williamalexander/Documents/coding/projects/LifeLens/server
   docker compose restart server
   ```

### "No data" on dashboard

1. Check the device ID in your `.env` file matches data in the database
2. Insert sample data for your device:
   ```bash
   curl -X POST http://192.168.1.87:8000/api/v1/ingest/health \
     -H "Content-Type: application/json" \
     -H "X-API-Key: test-key" \
     -d '{
       "device_id": "demo-device-macbook",
       "data_type": "steps",
       "value": 5000,
       "unit": "count",
       "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
     }'
   ```

## Tips

- Both devices can use the same server simultaneously
- Use different `VITE_DEVICE_ID` values to track data separately
- The server supports multiple devices - you can see data from all devices in the database
- For development, consider using `0.0.0.0` as CORS origin (not recommended for production)

## Production Considerations

For production deployment:
1. Use HTTPS instead of HTTP
2. Implement proper authentication (not just API keys)
3. Use specific domains instead of wildcards in CORS
4. Add rate limiting
5. Set up proper reverse proxy (nginx/traefik)
