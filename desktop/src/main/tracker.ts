import type { ProductivityRecord, ActiveWindow, Platform } from "@shared/types";

const PLATFORM: Platform = process.platform as Platform;

// Try to import active-win (may not be available on Linux)
let activeWin: any = null;
try {
  activeWin = require("active-win");
} catch (error) {
  console.warn("active-win not available. Window tracking disabled.");
}

/**
 * Productivity tracker - monitors active window and categorizes usage
 */
export class ProductivityTracker {
  private currentWindow: ActiveWindow | null = null;
  private windowStartTime: Date | null = null;
  private trackingInterval: NodeJS.Timeout | null = null;

  /**
   * Start tracking active windows
   */
  start(intervalSeconds: number = 5): void {
    if (!activeWin) {
      console.warn("Window tracking not available on this platform");
      return;
    }

    console.log(`Starting productivity tracker on ${PLATFORM}...`);
    this.trackWindow(); // Initial track

    this.trackingInterval = setInterval(() => {
      this.trackWindow();
    }, intervalSeconds * 1000);
  }

  /**
   * Stop tracking
   */
  stop(): void {
    if (this.trackingInterval) {
      clearInterval(this.trackingInterval);
      this.trackingInterval = null;
    }

    // Finalize current window session
    if (this.currentWindow && this.windowStartTime) {
      const record = this.createRecord(this.currentWindow, this.windowStartTime, new Date());
      this.logRecord(record);
    }
  }

  /**
   * Track current active window
   */
  private trackWindow(): void {
    if (!activeWin) return;

    activeWin()
      .then((window: ActiveWindow) => {
        if (!window) return;

        // Check if window changed
        if (!this.currentWindow || this.currentWindow.title !== window.title) {
          // Finalize previous window
          if (this.currentWindow && this.windowStartTime) {
            const record = this.createRecord(this.currentWindow, this.windowStartTime, new Date());
            this.logRecord(record);
            this.emitRecord(record);
          }

          // Start new window
          this.currentWindow = window;
          this.windowStartTime = new Date();
        }
      })
      .catch((error) => {
        console.error("Error tracking active window:", error);
      });
  }

  /**
   * Create productivity record from window data
   */
  private createRecord(
    window: ActiveWindow,
    startTime: Date,
    endTime: Date
  ): ProductivityRecord {
    const durationSeconds = Math.floor((endTime.getTime() - startTime.getTime()) / 1000);

    // Get input activity if available (Windows only)
    let inputActivity: { keystrokes_per_minute: number; clicks_per_minute: number } | undefined =
      undefined;

    if (PLATFORM === "win32") {
      try {
        // Dynamic import for Windows-only input monitor
        const { getInputMonitor } = require("./input-monitor");
        const inputMonitor = getInputMonitor();
        if (inputMonitor.isActiveMonitoring()) {
          inputActivity = inputMonitor.getActivity();
        }
      } catch (error) {
        // Input monitor not available, continue without it
      }
    }

    return {
      app_name: window.owner.name,
      window_title: window.title,
      category: this.categorizeApp(window.owner.name, window.title),
      duration_seconds: durationSeconds,
      input_activity: inputActivity
        ? {
            keystrokes_per_minute: inputActivity.keystrokes_per_minute,
            clicks_per_minute: inputActivity.clicks_per_minute,
          }
        : undefined,
      timestamp: startTime,
    };
  }

  /**
   * Categorize app based on name and title
   */
  private categorizeApp(appName: string, windowTitle?: string): ProductivityRecord["category"] {
    const lowerAppName = appName.toLowerCase();
    const lowerTitle = (windowTitle || "").toLowerCase();

    // Development/IDE
    if (
      lowerAppName.includes("vscode") ||
      lowerAppName.includes("intellij") ||
      lowerAppName.includes("pycharm") ||
      lowerAppName.includes("webstorm") ||
      lowerAppName.includes("xcode") ||
      lowerAppName.includes("android studio") ||
      lowerTitle.includes("visual studio")
    ) {
      return "work";
    }

    // Study/Documentation
    if (
      lowerTitle.includes("documentation") ||
      lowerTitle.includes("stack overflow") ||
      lowerTitle.includes("github") ||
      lowerTitle.includes("gitlab") ||
      lowerAppName.includes("safari") ||
      lowerAppName.includes("chrome") && (lowerTitle.includes("wikipedia") || lowerTitle.includes("docs."))
    ) {
      return "study";
    }

    // Communication
    if (
      lowerAppName.includes("slack") ||
      lowerAppName.includes("teams") ||
      lowerAppName.includes("discord") ||
      lowerAppName.includes("zoom") ||
      lowerAppName.includes("skype")
    ) {
      return "communication";
    }

    // Leisure
    if (
      lowerAppName.includes("youtube") ||
      lowerAppName.includes("netflix") ||
      lowerAppName.includes("spotify") ||
      lowerAppName.includes("games") ||
      lowerAppName.includes("steam")
    ) {
      return "leisure";
    }

    // Default to work for unknown apps
    return "work";
  }

  /**
   * Log record to console (in production, would sync to server)
   */
  private logRecord(record: ProductivityRecord): void {
    console.log(`[${record.category?.toUpperCase()}] ${record.app_name}: ${record.duration_seconds}s`);
  }

  /**
   * Emit record for sync service to pick up (event emitter in production)
   */
  private emitRecord(record: ProductivityRecord): void {
    // TODO: In production, emit to sync service for batching
    // For now, just log it
    console.log("Record emitted for sync:", record.app_name, record.duration_seconds, "seconds");
  }
}

// Singleton instance
let trackerInstance: ProductivityTracker | null = null;

export function getTracker(): ProductivityTracker {
  if (!trackerInstance) {
    trackerInstance = new ProductivityTracker();
  }
  return trackerInstance;
}
