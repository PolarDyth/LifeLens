import type { Platform } from "@shared/types";

const PLATFORM: Platform = process.platform as Platform;

/**
 * Input activity monitor - tracks keyboard and mouse usage
 */
export class InputMonitor {
  private keystrokesPerMinute: number = 0;
  private clicksPerMinute: number = 0;
  private keystrokeCount: number = 0;
  private clickCount: number = 0;
  private resetInterval: NodeJS.Timeout | null = null;
  private isActive: boolean = false;
  private ioHook: any = null; // Type will be resolved at runtime

  constructor() {
    this.startMinuteCounter();
  }

  /**
   * Start monitoring input activity
   */
  async start(): Promise<void> {
    if (this.isActive) {
      console.log("Input monitor already active");
      return;
    }

    if (PLATFORM === "win32") {
      // Windows: Use uiohook-napi for global keyboard/mouse hooks
      try {
        const uiohook = require("uiohook-napi");
        this.ioHook = uiohook;

        uiohook.on("keydown", (event: any) => {
          this.keystrokeCount++;
        });

        uiohook.on("mouseup", (event: any) => {
          this.clickCount++;
        });

        uiohook.start();
        this.isActive = true;
        console.log("✓ Input monitoring started (Windows)");
      } catch (error) {
        console.error("Failed to start input monitoring (Windows):", error);
        console.warn("Input monitoring requires administrator privileges or uiohook-napi");
      }
    } else if (PLATFORM === "darwin") {
      // macOS: Use CGEvent tap (requires accessibility)
      console.log("Input monitoring not yet implemented for macOS");
    } else if (PLATFORM === "linux") {
      console.log("Input monitoring not yet implemented for Linux");
    }
  }

  /**
   * Stop monitoring
   */
  stop(): void {
    if (this.ioHook && PLATFORM === "win32") {
      try {
        this.ioHook.stop();
        this.isActive = false;
        console.log("Input monitoring stopped");
      } catch (error) {
        console.error("Error stopping input monitoring:", error);
      }
    }
  }

  /**
   * Start minute counter that resets rates every minute
   */
  private startMinuteCounter(): void {
    this.resetInterval = setInterval(() => {
      // Calculate rates per minute
      this.keystrokesPerMinute = this.keystrokeCount;
      this.clicksPerMinute = this.clickCount;

      // Reset counters
      this.keystrokeCount = 0;
      this.clickCount = 0;

      // Log every minute (in production, would emit event)
      if (this.keystrokesPerMinute > 0 || this.clicksPerMinute > 0) {
        console.log(`Input activity: ${this.keystrokesPerMinute} keys/min, ${this.clicksPerMinute} clicks/min`);
      }
    }, 60 * 1000); // Every 60 seconds
  }

  /**
   * Get current input activity metrics
   */
  getActivity(): { keystrokes_per_minute: number; clicks_per_minute: number } {
    return {
      keystrokes_per_minute: this.keystrokesPerMinute,
      clicks_per_minute: this.clicksPerMinute,
    };
  }

  /**
   * Check if input monitor is active
   */
  isActiveMonitoring(): boolean {
    return this.isActive;
  }
}

// Singleton instance
let monitorInstance: InputMonitor | null = null;

export function getInputMonitor(): InputMonitor {
  if (!monitorInstance) {
    monitorInstance = new InputMonitor();
  }
  return monitorInstance;
}
