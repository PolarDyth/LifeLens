const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8000";
const API_KEY = import.meta.env.VITE_API_KEY || "test-key";

export interface HealthData {
  device_id: string;
  data_type: string;
  value: number;
  unit: string;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export interface ProductivityData {
  device_id: string;
  app_name: string;
  window_title?: string;
  category?: string;
  duration_seconds: number;
  input_activity?: Record<string, number>;
  timestamp: string;
  platform: string;
}

export interface LocationData {
  device_id: string;
  location_type: string;
  latitude?: number;
  longitude?: number;
  place_name?: string;
  horizontal_accuracy?: number;
  timestamp: string;
}

export interface HealthSummary {
  device_id: string;
  date: string;
  steps: number;
  avg_heart_rate: number | null;
  min_heart_rate: number | null;
  max_heart_rate: number | null;
  sleep_duration_hours: number | null;
  active_calories: number | null;
  distance_km: number | null;
}

export interface ProductivityBreakdown {
  device_id: string;
  date: string;
  work_seconds: number;
  study_seconds: number;
  leisure_seconds: number;
  communication_seconds: number;
  other_seconds: number;
  total_seconds: number;
}

export interface LocationTrack {
  device_id: string;
  timestamp: string;
  latitude: number;
  longitude: number;
  location_type: string;
  place_name: string | null;
}

export interface HealthDailyData {
  date: string;
  steps: number;
  avg_heart_rate: number | null;
  min_heart_rate: number | null;
  max_heart_rate: number | null;
  active_calories: number;
}

export interface ProductivityByApp {
  app_name: string;
  duration_seconds: number;
  category: string;
}

export interface LocationStats {
  device_id: string;
  date: string;
  distance_km: number;
  places_visited: number;
  time_outside_minutes: number;
}

class APIClient {
  private baseURL: string;
  private apiKey: string;

  constructor(baseURL: string, apiKey: string) {
    this.baseURL = baseURL;
    this.apiKey = apiKey;
  }

  private async request<T>(
    endpoint: string,
    options?: RequestInit,
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": this.apiKey,
        ...options?.headers,
      },
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  async healthCheck(): Promise<{ status: string; version: string }> {
    return this.request<{ status: string; version: string }>("/health");
  }

  async ingestHealth(data: HealthData): Promise<{ message: string; record_count: number }> {
    return this.request("/api/v1/ingest/health", {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  async ingestProductivity(data: ProductivityData): Promise<{ message: string; record_count: number }> {
    return this.request("/api/v1/ingest/productivity", {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  async ingestLocation(data: LocationData): Promise<{ message: string; record_count: number }> {
    return this.request("/api/v1/ingest/location", {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  async getHealthToday(deviceId: string): Promise<HealthSummary> {
    return this.request(`/api/v1/query/health/today?device_id=${encodeURIComponent(deviceId)}`);
  }

  async getProductivityToday(deviceId: string): Promise<ProductivityBreakdown> {
    return this.request(`/api/v1/query/productivity/today?device_id=${encodeURIComponent(deviceId)}`);
  }

  async getRecentLocations(deviceId: string, limit = 100): Promise<LocationTrack[]> {
    return this.request(
      `/api/v1/query/location/recent?device_id=${encodeURIComponent(deviceId)}&limit=${limit}`,
    );
  }

  async getHealthHistory(deviceId: string, days = 7): Promise<HealthDailyData[]> {
    return this.request(
      `/api/v1/query/health/history?device_id=${encodeURIComponent(deviceId)}&days=${days}`,
    );
  }

  async getProductivityByApp(deviceId: string): Promise<ProductivityByApp[]> {
    return this.request(
      `/api/v1/query/productivity/by-app?device_id=${encodeURIComponent(deviceId)}`,
    );
  }

  async getLocationStats(deviceId: string): Promise<LocationStats> {
    return this.request(
      `/api/v1/query/location/stats?device_id=${encodeURIComponent(deviceId)}`,
    );
  }
}

export const apiClient = new APIClient(API_BASE_URL, API_KEY);
