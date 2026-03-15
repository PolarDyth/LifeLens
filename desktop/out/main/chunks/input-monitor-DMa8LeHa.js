import __cjs_mod__ from "node:module";
const __filename = import.meta.filename;
const __dirname = import.meta.dirname;
const require2 = __cjs_mod__.createRequire(import.meta.url);
const PLATFORM = process.platform;
class InputMonitor {
  keystrokesPerMinute = 0;
  clicksPerMinute = 0;
  keystrokeCount = 0;
  clickCount = 0;
  resetInterval = null;
  isActive = false;
  ioHook = null;
  // Type will be resolved at runtime
  constructor() {
    this.startMinuteCounter();
  }
  /**
   * Start monitoring input activity
   */
  async start() {
    if (this.isActive) {
      console.log("Input monitor already active");
      return;
    }
    if (PLATFORM === "win32") {
      try {
        const uiohook = require2("uiohook-napi");
        this.ioHook = uiohook;
        uiohook.on("keydown", (event) => {
          this.keystrokeCount++;
        });
        uiohook.on("mouseup", (event) => {
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
      console.log("Input monitoring not yet implemented for macOS");
    } else if (PLATFORM === "linux") {
      console.log("Input monitoring not yet implemented for Linux");
    }
  }
  /**
   * Stop monitoring
   */
  stop() {
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
  startMinuteCounter() {
    this.resetInterval = setInterval(() => {
      this.keystrokesPerMinute = this.keystrokeCount;
      this.clicksPerMinute = this.clickCount;
      this.keystrokeCount = 0;
      this.clickCount = 0;
      if (this.keystrokesPerMinute > 0 || this.clicksPerMinute > 0) {
        console.log(`Input activity: ${this.keystrokesPerMinute} keys/min, ${this.clicksPerMinute} clicks/min`);
      }
    }, 60 * 1e3);
  }
  /**
   * Get current input activity metrics
   */
  getActivity() {
    return {
      keystrokes_per_minute: this.keystrokesPerMinute,
      clicks_per_minute: this.clicksPerMinute
    };
  }
  /**
   * Check if input monitor is active
   */
  isActiveMonitoring() {
    return this.isActive;
  }
}
let monitorInstance = null;
function getInputMonitor() {
  if (!monitorInstance) {
    monitorInstance = new InputMonitor();
  }
  return monitorInstance;
}
export {
  InputMonitor,
  getInputMonitor
};
