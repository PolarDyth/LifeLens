import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { apiClient, type HealthSummary, type ProductivityBreakdown } from "@/lib/api";

interface DashboardProps {
  onUpdate: (date: Date) => void;
}

interface DashboardStats {
  stepsToday: number;
  screenTime: string;
  activeHours: number;
  lastSync: Date;
  productivity: {
    work: number;
    study: number;
    leisure: number;
    total_seconds: number;
  };
  sleep: {
    duration: string;
    quality: number;
  };
  heartRate: {
    avg: number | null;
    min: number | null;
    max: number | null;
  };
  distance: number | null;
  activeCalories: number | null;
}

const DEVICE_ID = import.meta.env.VITE_DEVICE_ID || "default-device";
console.log('Dashboard using device_id:', DEVICE_ID);
console.log('API URL:', import.meta.env.VITE_API_URL);

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${hours}h ${minutes}m`;
}

export function Dashboard({ onUpdate }: DashboardProps) {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [healthData, productivityData] = await Promise.all([
          apiClient.getHealthToday(DEVICE_ID),
          apiClient.getProductivityToday(DEVICE_ID),
        ]);

        console.log('Health data:', healthData);
        console.log('Productivity data:', productivityData);

        const totalSeconds = productivityData.total_seconds;
        const activeSeconds = productivityData.work_seconds + productivityData.study_seconds;
        const activeHours = activeSeconds / 3600;

        const newStats = {
          stepsToday: healthData.steps,
          screenTime: formatDuration(totalSeconds),
          activeHours: Math.round(activeHours * 10) / 10,
          lastSync: new Date(),
          productivity: {
            work: productivityData.work_seconds,
            study: productivityData.study_seconds,
            leisure: productivityData.leisure_seconds,
            total_seconds: totalSeconds,
          },
          sleep: {
            duration: healthData.sleep_duration_hours
              ? formatDuration(healthData.sleep_duration_hours * 3600)
              : "N/A",
            quality: 0,
          },
          heartRate: {
            avg: healthData.avg_heart_rate,
            min: healthData.min_heart_rate,
            max: healthData.max_heart_rate,
          },
          distance: healthData.distance_km,
          activeCalories: healthData.active_calories,
        };

        console.log('Setting stats:', newStats);
        setStats(newStats);

        setLastUpdated(new Date());
        setError(null);
      } catch (err) {
        console.error("Failed to fetch dashboard stats:", err);
        setError("Failed to load data. Check server connection.");
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 2 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="p-8 space-y-4">
        <div className="text-xl font-semibold">Loading dashboard...</div>
        <div className="text-sm text-muted-foreground">Fetching data from server...</div>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div className="p-8">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-red-800">{error || "Failed to load dashboard data"}</p>
          <p className="text-sm text-red-600 mt-2">
            Ensure the server is running at {apiClient["baseURL"] || "http://localhost:8000"}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
          <p className="text-muted-foreground">
            Overview of your life metrics today
          </p>
        </div>
        {lastUpdated && (
          <p className="text-sm text-muted-foreground">
            Last updated: {lastUpdated.toLocaleTimeString()}
            {Date.now() - lastUpdated.getTime() > 2 * 60 * 1000 && (
            <span className="text-yellow-600 ml-2">⚠ Data may be stale</span>
            )}
          </p>
        )}
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Steps Today
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-foreground" >{stats.stepsToday.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground mt-1">
              12% above 7-day average
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Screen Time
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold" >{stats.screenTime}</div>
            <p className="text-xs text-muted-foreground mt-1">
              {formatDuration(stats.productivity.work)} work, {formatDuration(stats.productivity.study)} study
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Active Hours
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold" >{stats.activeHours}h</div>
            <p className="text-xs text-muted-foreground mt-1">
              {stats.heartRate.avg ? `${Math.round(stats.heartRate.avg)} BPM avg` : "No heart rate data"}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Sleep
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold" >{stats.sleep.duration}</div>
            <p className="text-xs text-muted-foreground mt-1">
              {stats.distance ? `${stats.distance.toFixed(1)} km distance` : "No distance data"}
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Productivity Today</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center gap-4">
                <span className="text-sm w-20">Work</span>
                <div className="flex items-center gap-2 flex-1">
                  <div className="w-full max-w-[200px] bg-secondary rounded-full h-2 overflow-hidden">
                    <div
                      className="bg-primary h-2 rounded-full transition-all"
                      style={{
                        width: `${stats.productivity.total_seconds > 0 ? Math.min(100, (stats.productivity.work / stats.productivity.total_seconds) * 100) : 0}%`,
                      }}
                    />
                  </div>
                  <span className="text-sm font-medium w-20 text-right">{formatDuration(stats.productivity.work)}</span>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <span className="text-sm w-20">Study</span>
                <div className="flex items-center gap-2 flex-1">
                  <div className="w-full max-w-[200px] bg-secondary rounded-full h-2 overflow-hidden">
                    <div
                      className="bg-blue-500 h-2 rounded-full transition-all"
                      style={{
                        width: `${stats.productivity.total_seconds > 0 ? Math.min(100, (stats.productivity.study / stats.productivity.total_seconds) * 100) : 0}%`,
                      }}
                    />
                  </div>
                  <span className="text-sm font-medium w-20 text-right">{formatDuration(stats.productivity.study)}</span>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <span className="text-sm w-20">Leisure</span>
                <div className="flex items-center gap-2 flex-1">
                  <div className="w-full max-w-[200px] bg-secondary rounded-full h-2 overflow-hidden">
                    <div
                      className="bg-green-500 h-2 rounded-full transition-all"
                      style={{
                        width: `${stats.productivity.total_seconds > 0 ? Math.min(100, (stats.productivity.leisure / stats.productivity.total_seconds) * 100) : 0}%`,
                      }}
                    />
                  </div>
                  <span className="text-sm font-medium w-20 text-right">{formatDuration(stats.productivity.leisure)}</span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Weekly Trends</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 text-sm">
              <p className="text-muted-foreground">
                📈 Your resting heart rate dropped from 68 to 62 BPM this week (improving fitness)
              </p>
              <p className="text-muted-foreground">
                😴 Sleep average: 6h 32m (below 7h target)
              </p>
              <p className="text-muted-foreground">
                💪 Productive time increased 15% vs last week
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
