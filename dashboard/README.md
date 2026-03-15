# LifeLens Dashboard

React web application for visualizing life tracking data.

## Prerequisites

- Node.js 20+
- npm or yarn

## Quick Start

1. Install dependencies:
```bash
cd dashboard
npm install
```

2. Start development server:
```bash
npm run dev
```

3. Open http://localhost:5173 in your browser

## Configuration

Environment variables (create `.env` file):
```
VITE_API_URL=http://localhost:8000
VITE_API_KEY=test-key
```

## Features

- **Dashboard**: Overview cards showing today's metrics
- **Health**: Steps, heart rate, sleep, and workout charts
- **Productivity**: Screen time breakdown and focus trends
- **Location**: GPS tracks and place visits on map
- **Dark mode**: Automatically detects system preference

## Build

```bash
npm run build
```

Optimized bundle will be in `dist/` directory.

## Development

- Component library: shadcn/ui (https://ui.shadcn.com/)
- Charts: Recharts (https://recharts.org/)
- Routing: React Router v6
- State: React hooks + TanStack Query (planned)

## Notes

- Dashboard updates data every 30 seconds
- "Last updated" timestamp shows freshness
- Responsive design works on mobile devices
