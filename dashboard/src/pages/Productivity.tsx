import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { apiClient, type ProductivityByApp, type ProductivityBreakdown } from "@/lib/api";

interface ProductivityProps {
  onUpdate: (date: Date) => void;
}

const DEVICE_ID = import.meta.env.VITE_DEVICE_ID || "default-device";

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${hours}h ${minutes}m`;
}

const categoryColors: Record<string, string> = {
  work: "bg-blue-500",
  study: "bg-purple-500",
  leisure: "bg-green-500",
  communication: "bg-yellow-500",
  other: "bg-gray-500",
};

export function Productivity({ onUpdate }: ProductivityProps) {
  const [appsByTime, setAppsByTime] = useState<ProductivityByApp[]>([]);
  const [breakdown, setBreakdown] = useState<ProductivityBreakdown | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [appsData, breakdownData] = await Promise.all([
          apiClient.getProductivityByApp(DEVICE_ID),
          apiClient.getProductivityToday(DEVICE_ID),
        ]);
        setAppsByTime(appsData);
        setBreakdown(breakdownData);
        setError(null);
      } catch (err) {
        console.error("Failed to fetch productivity data:", err);
        setError("Failed to load productivity data");
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
          <h2 className="text-3xl font-bold tracking-tight">Productivity</h2>
          <p className="text-muted-foreground">Track your screen time, app usage, and focus patterns</p>
        </div>
        <div className="text-muted-foreground">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-8">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Productivity</h2>
          <p className="text-muted-foreground">Track your screen time, app usage, and focus patterns</p>
        </div>
        <div className="text-red-600">{error}</div>
      </div>
    );
  }

  const totalScreenTime = breakdown?.total_seconds || 0;
  const maxAppTime = Math.max(...appsByTime.map((app) => app.duration_seconds), 1);

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Productivity</h2>
        <p className="text-muted-foreground">
          Track your screen time, app usage, and focus patterns
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Screen Time by App (Today)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {appsByTime.slice(0, 8).map((app) => {
                const widthPercent = (app.duration_seconds / maxAppTime) * 100;
                const colorClass = categoryColors[app.category] || categoryColors.other;
                return (
                  <div key={app.app_name} className="flex items-center gap-3">
                    <div className="w-32 text-sm truncate" title={app.app_name}>
                      {app.app_name}
                    </div>
                    <div className="flex-1 flex items-center gap-2">
                      <div className="w-full max-w-[180px] bg-secondary rounded-full h-2 overflow-hidden">
                        <div
                          className={`${colorClass} h-2 rounded-full transition-all`}
                          style={{ width: `${widthPercent}%` }}
                        />
                      </div>
                      <div className="text-sm font-medium w-16 text-right text-foreground">
                        {formatDuration(app.duration_seconds)}
                      </div>
                    </div>
                  </div>
                );
              })}
              {appsByTime.length === 0 && (
                <div className="text-sm text-muted-foreground">No app usage data for today</div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Category Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {breakdown && totalScreenTime > 0 ? (
                <>
                  <div className="flex items-center gap-4">
                    <span className="text-sm w-24">Work</span>
                    <div className="flex items-center gap-2 flex-1">
                      <div className="w-full max-w-[200px] bg-secondary rounded-full h-3 overflow-hidden">
                        <div
                          className="bg-blue-500 h-3 rounded-full transition-all"
                          style={{ width: `${(breakdown.work_seconds / totalScreenTime) * 100}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium w-20 text-right text-foreground">
                        {formatDuration(breakdown.work_seconds)}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-sm w-24">Study</span>
                    <div className="flex items-center gap-2 flex-1">
                      <div className="w-full max-w-[200px] bg-secondary rounded-full h-3 overflow-hidden">
                        <div
                          className="bg-purple-500 h-3 rounded-full transition-all"
                          style={{ width: `${(breakdown.study_seconds / totalScreenTime) * 100}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium w-20 text-right text-foreground">
                        {formatDuration(breakdown.study_seconds)}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-sm w-24">Leisure</span>
                    <div className="flex items-center gap-2 flex-1">
                      <div className="w-full max-w-[200px] bg-secondary rounded-full h-3 overflow-hidden">
                        <div
                          className="bg-green-500 h-3 rounded-full transition-all"
                          style={{ width: `${(breakdown.leisure_seconds / totalScreenTime) * 100}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium w-20 text-right text-foreground">
                        {formatDuration(breakdown.leisure_seconds)}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-sm w-24">Communication</span>
                    <div className="flex items-center gap-2 flex-1">
                      <div className="w-full max-w-[200px] bg-secondary rounded-full h-3 overflow-hidden">
                        <div
                          className="bg-yellow-500 h-3 rounded-full transition-all"
                          style={{ width: `${(breakdown.communication_seconds / totalScreenTime) * 100}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium w-20 text-right text-foreground">
                        {formatDuration(breakdown.communication_seconds)}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-sm w-24">Other</span>
                    <div className="flex items-center gap-2 flex-1">
                      <div className="w-full max-w-[200px] bg-secondary rounded-full h-3 overflow-hidden">
                        <div
                          className="bg-gray-500 h-3 rounded-full transition-all"
                          style={{ width: `${(breakdown.other_seconds / totalScreenTime) * 100}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium w-20 text-right text-foreground">
                        {formatDuration(breakdown.other_seconds)}
                      </span>
                    </div>
                  </div>
                </>
              ) : (
                <div className="text-sm text-muted-foreground">No screen time data for today</div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Total Screen Time</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-center">
              <div className="text-5xl font-bold mb-2 text-foreground">
                {formatDuration(totalScreenTime)}
              </div>
              <div className="text-sm text-muted-foreground">Today</div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Productivity Score</CardTitle>
          </CardHeader>
          <CardContent>
            {breakdown && totalScreenTime > 0 ? (
              <div className="text-center">
                <div className="text-5xl font-bold mb-2 text-foreground">
                  {Math.round(((breakdown.work_seconds + breakdown.study_seconds) / totalScreenTime) * 100)}%
                </div>
                <div className="text-sm text-muted-foreground">Productive time</div>
                <div className="text-xs text-muted-foreground mt-2">
                  Work + Study / Total Screen Time
                </div>
              </div>
            ) : (
              <div className="text-center text-muted-foreground">No data available</div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
