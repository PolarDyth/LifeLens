/** Productivity data tracked from desktop usage */
export interface ProductivityRecord {
  app_name: string;
  window_title?: string;
  category?: "work" | "study" | "leisure" | "communication" | "other";
  duration_seconds: number;
  input_activity?: {
    keystrokes_per_minute: number;
    clicks_per_minute: number;
  };
  timestamp: Date;
}

/** Active window information */
export interface ActiveWindow {
  title: string;
  owner: {
    name: string;
    processId: number;
  };
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
}

/** Platform information */
export type Platform = "macos" | "windows" | "linux";

/** Configuration stored locally */
export interface Config {
  serverUrl: string;
  apiKey: string;
  device_id: string;
  trackingIntervalSeconds: number;
  uploadIntervalMinutes: number;
  platform: Platform;
}

/** Sync queue item for offline resilience */
export interface QueueItem {
  id: string;
  type: "productivity";
  data: ProductivityRecord[];
  timestamp: Date;
  retryCount: number;
  lastError?: string;
}
