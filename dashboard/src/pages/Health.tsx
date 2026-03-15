import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { apiClient, type HealthDailyData } from "@/lib/api";

interface HealthProps {
  onUpdate: (date: Date) => void;
}

const DEVICE_ID = import.meta.env.VITE_DEVICE_ID || "default-device";

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${hours}h ${minutes}m`;
}

export function Health({ onUpdate }: HealthProps) {
  const [healthHistory, setHealthHistory] = useState<HealthDailyData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const data = await apiClient.getHealthHistory(DEVICE_ID, 7);
        setHealthHistory(data);
        setError(null);
      } catch (err) {
        console.error("Failed to fetch health data:", err);
        setError("Failed to load health data");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="space-y-8">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Health & Fitness</h2>
          <p className="text-muted-foreground">Track your steps, heart rate, sleep, and workouts</p>
        </div>
        <div className="text-muted-foreground">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-8">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Health & Fitness</h2>
          <p className="text-muted-foreground">Track your steps, heart rate, sleep, and workouts</p>
        </div>
        <div className="text-red-600">{error}</div>
      </div>
    );
  }

  const maxSteps = Math.max(...healthHistory.map((d) => d.steps), 1);

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Health & Fitness</h2>
        <p className="text-muted-foreground">
          Track your steps, heart rate, sleep, and workouts
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Steps (Last 7 Days)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-64 flex items-end justify-between gap-2">
              {healthHistory.map((day) => {
                const heightPercent = Math.max((day.steps / maxSteps) * 100, 4);
                const dateLabel = new Date(day.date).toLocaleDateString("en-US", { weekday: "short" });
                return (
                  <div key={day.date} className="flex flex-col items-center gap-2 flex-1">
                    <div
                      className="w-full bg-primary rounded-t transition-all hover:opacity-80 relative group"
                      style={{ height: `${heightPercent}%` }}
                      title={`${day.steps} steps`}
                    >
                      <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-popover text-popover-foreground text-xs px-2 py-1 rounded shadow opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                        {day.steps.toLocaleString()} steps
                      </div>
                    </div>
                    <div className="text-xs text-muted-foreground">{dateLabel}</div>
                    <div className="text-xs font-medium text-foreground">{day.steps.toLocaleString()}</div>
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Heart Rate Trends</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {healthHistory.slice(-5).reverse().map((day) => {
                const dateLabel = new Date(day.date).toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" });
                return (
                  <div key={day.date} className="flex items-center gap-4">
                    <div className="w-32 text-sm text-muted-foreground">{dateLabel}</div>
                    <div className="flex-1">
                      {day.avg_heart_rate ? (
                        <div className="flex items-center gap-4">
                          <div className="text-2xl font-bold text-foreground">
                            {Math.round(day.avg_heart_rate)}
                          </div>
                          <div className="text-sm text-muted-foreground">
                            BPM avg (range: {day.min_heart_rate || "-"} - {day.max_heart_rate || "-"})
                          </div>
                        </div>
                      ) : (
                        <div className="text-sm text-muted-foreground">No data</div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Sleep Analysis</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-64 flex items-center justify-center text-muted-foreground">
              <div className="text-center">
                <div className="text-4xl mb-2">😴</div>
                <div>Sleep tracking not yet available</div>
                <div className="text-sm mt-2">Connect a sleep tracker to see sleep patterns</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Active Energy</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {healthHistory.slice(-5).reverse().map((day) => {
                const dateLabel = new Date(day.date).toLocaleDateString("en-US", { weekday: "short" });
                const calories = day.active_calories || 0;
                const maxCalories = Math.max(...healthHistory.map((d) => d.active_calories || 0), 1);
                const widthPercent = (calories / maxCalories) * 100;
                return (
                  <div key={day.date} className="flex items-center gap-4">
                    <div className="w-20 text-sm text-muted-foreground">{dateLabel}</div>
                    <div className="flex-1 flex items-center gap-2">
                      <div className="w-full max-w-[200px] bg-secondary rounded-full h-2 overflow-hidden">
                        <div
                          className="bg-orange-500 h-2 rounded-full transition-all"
                          style={{ width: `${widthPercent}%` }}
                        />
                      </div>
                      <div className="text-sm font-medium w-16 text-foreground">
                        {calories.toLocaleString()}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
