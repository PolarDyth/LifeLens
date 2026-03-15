import { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain } from "electron";
import path from "path";
import os from "os";
import { getTracker } from "./tracker";
import { getSyncService } from "./sync";

const isDev = process.env.NODE_ENV === "development";
const platform = os.platform() as "darwin" | "win32" | "linux";

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let isQuitting = false;

// IPC handlers for renderer process
ipcMain.handle("get-config", async () => {
  return {
    serverUrl: process.env.LIFLENS_SERVER_URL || "http://localhost:8000",
    apiKey: process.env.LIFLENS_API_KEY || "test-key",
    device_id: `desktop-${os.platform()}-${os.hostname()}`,
    trackingIntervalSeconds: 5,
    uploadIntervalMinutes: 5,
    platform: os.platform(),
  };
});

ipcMain.handle("sync-now", async () => {
  const syncService = getSyncService();
  await syncService.manualSync();
  return { success: true };
});

ipcMain.handle("get-queue-status", async () => {
  const syncService = getSyncService();
  return syncService.getQueueStatus();
});

ipcMain.handle("get-productivity-records", async () => {
  // TODO: Return actual productivity records from tracker
  return [];
});

// Create system tray icon
function createTray() {
  // Note: In production, you'd use actual icon files
  // For now, we'll create an empty tray (icon will be added later)
  if (platform === "darwin" || platform === "win32") {
    tray = new Tray(
      nativeImage.createFromPath(path.join(__dirname, "../../../build/icon.png")).resize({ width: 16, height: 16 })
    );

    const contextMenu = Menu.buildFromTemplate([
      { label: "Show LifeLens", click: () => showMainWindow() },
      { label: "Quit LifeLens", click: () => app.quit() },
    ]);

    tray.setToolTip("LifeLens - Tracking your productivity");
    tray.setContextMenu(contextMenu);
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    show: false, // Don't show initially, only show in tray
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "../preload/index.js"),
      sandbox: false,
    },
  });

  // Load the app
  if (isDev) {
    mainWindow.loadURL("http://localhost:5173");
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, "../renderer/index.html"));
  }

  mainWindow.on("close", (event) => {
    // Prevent window close, hide to tray instead
    if (!isQuitting) {
      event.preventDefault();
      mainWindow?.hide();
    }
  });
}

function showMainWindow() {
  if (mainWindow) {
    mainWindow.show();
    mainWindow.focus();
  }
}

// Check accessibility permissions on macOS
async function checkAccessibilityPermissions() {
  if (platform === "darwin") {
    // macOS requires accessibility permissions for active window tracking
    // We'll show a one-time prompt on first launch
    const { exec } = require("child_process");

    return new Promise<boolean>((resolve) => {
      exec(
        "osascript -e 'tell application \"System Events\" to get name of every process whose background only is false'",
        (error) => {
          if (error) {
            console.log("Accessibility permissions not granted. Please grant in System Settings.");
            resolve(false);
          } else {
            console.log("Accessibility permissions granted.");
            resolve(true);
          }
        }
      );
    });
  }
  return true;
}

// App lifecycle
app.whenReady().then(() => {
  checkAccessibilityPermissions();
  createWindow();
  createTray();

  // Start tracking services
  const tracker = getTracker();
  const syncService = getSyncService();

  if (isDev) {
    console.log("Development mode - tracking services starting");
  }

  // Start window tracking (polls every 5 seconds)
  tracker.start(5);

  // Start input monitoring (Windows only for now)
  if (platform === "win32") {
    // Dynamic import for Windows-only dependency
    import("./input-monitor").then(({ getInputMonitor }) => {
      getInputMonitor().start().catch((error) => {
        console.error("Failed to start input monitor:", error);
        console.warn("Continuing without input monitoring");
      });
    }).catch((error) => {
      console.warn("Input monitor not available:", error.message);
    });
  }

  // Start periodic sync (every 5 minutes)
  syncService.start(5);

  if (isDev) {
    console.log("Development mode - all services started");
  }
});

app.on("window-all-closed", () => {
  // Don't quit on macOS when all windows are closed (we have tray icon)
  if (platform !== "darwin") {
    app.quit();
  }
});

app.on("before-quit", () => {
  // Set quitting flag
  isQuitting = true;

  // Cleanup
  if (mainWindow) {
    mainWindow = null;
  }
  if (tray) {
    tray.destroy();
    tray = null;
  }
});
