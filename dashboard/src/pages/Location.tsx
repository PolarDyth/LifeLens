import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { apiClient, type LocationTrack, type LocationStats } from "@/lib/api";

interface LocationProps {
  onUpdate: (date: Date) => void;
}

const DEVICE_ID = import.meta.env.VITE_DEVICE_ID || "default-device";

export function Location({ onUpdate }: LocationProps) {
  const [locations, setLocations] = useState<LocationTrack[]>([]);
  const [stats, setStats] = useState<LocationStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [locationsData, statsData] = await Promise.all([
          apiClient.getRecentLocations(DEVICE_ID, 50),
          apiClient.getLocationStats(DEVICE_ID),
        ]);
        setLocations(locationsData);
        setStats(statsData);
        setError(null);
      } catch (err) {
        console.error("Failed to fetch location data:", err);
        setError("Failed to load location data");
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
          <h2 className="text-3xl font-bold tracking-tight">Location & Movement</h2>
          <p className="text-muted-foreground">Track your GPS tracks, place visits, and travel patterns</p>
        </div>
        <div className="text-muted-foreground">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-8">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Location & Movement</h2>
          <p className="text-muted-foreground">Track your GPS tracks, place visits, and travel patterns</p>
        </div>
        <div className="text-red-600">{error}</div>
      </div>
    );
  }

  const placeVisits = locations.filter((loc) => loc.location_type === "place_visit" && loc.place_name);

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Location & Movement</h2>
        <p className="text-muted-foreground">
          Track your GPS tracks, place visits, and travel patterns
        </p>
      </div>

      <div className="grid gap-4">
        <Card>
          <CardHeader>
            <CardTitle>Travel Summary</CardTitle>
          </CardHeader>
          <CardContent>
            {stats ? (
              <div className="grid gap-4 md:grid-cols-3">
                <div className="text-center">
                  <div className="text-3xl font-bold text-foreground">
                    {stats.distance_km.toFixed(1)} km
                  </div>
                  <div className="text-sm text-muted-foreground">Distance Today</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-foreground">
                    {stats.places_visited}
                  </div>
                  <div className="text-sm text-muted-foreground">Places Visited</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-foreground">
                    {stats.time_outside_minutes} min
                  </div>
                  <div className="text-sm text-muted-foreground">Time Outside</div>
                </div>
              </div>
            ) : (
              <div className="text-center text-muted-foreground">No travel data available</div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Recent Location Activity</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {locations.length > 0 ? (
                locations.slice(0, 10).map((loc, idx) => {
                  const time = new Date(loc.timestamp).toLocaleTimeString("en-US", {
                    hour: "2-digit",
                    minute: "2-digit",
                  });
                  return (
                    <div key={`${loc.timestamp}-${idx}`} className="flex items-center gap-4 text-sm">
                      <div className="w-20 text-muted-foreground">{time}</div>
                      <div className="flex-1">
                        {loc.location_type === "place_visit" && loc.place_name ? (
                          <div>
                            <span className="font-medium text-foreground">
                              {loc.place_name}
                            </span>
                            <span className="text-muted-foreground ml-2">(Place Visit)</span>
                          </div>
                        ) : (
                          <div className="text-muted-foreground">
                            GPS Track: {loc.latitude.toFixed(4)}, {loc.longitude.toFixed(4)}
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="text-sm text-muted-foreground">No location data available</div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Places Visited</CardTitle>
          </CardHeader>
          <CardContent>
            {placeVisits.length > 0 ? (
              <div className="space-y-2">
                {placeVisits.map((loc, idx) => {
                  const time = new Date(loc.timestamp).toLocaleString("en-US", {
                    weekday: "short",
                    month: "short",
                    day: "numeric",
                    hour: "2-digit",
                    minute: "2-digit",
                  });
                  return (
                    <div key={`${loc.timestamp}-${idx}`} className="flex items-center justify-between p-3 bg-secondary rounded">
                      <div>
                        <div className="font-medium text-foreground">
                          {loc.place_name}
                        </div>
                        <div className="text-xs text-muted-foreground mt-1">{time}</div>
                      </div>
                      <div className="text-xs text-muted-foreground">
                        {loc.latitude.toFixed(4)}, {loc.longitude.toFixed(4)}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="h-32 flex items-center justify-center text-muted-foreground">
                <div className="text-center">
                  <div className="text-4xl mb-2">📍</div>
                  <div>No places visited yet</div>
                  <div className="text-sm mt-2">Location tracking will show place visits here</div>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
