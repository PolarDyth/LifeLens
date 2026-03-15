import { contextBridge, ipcRenderer } from "electron";
import type { ProductivityRecord, Config } from "@shared/types";

// Expose protected methods to renderer process
contextBridge.exposeInMainProcess("electronAPI", {
  getProductivityRecords: () => ipcRenderer.invoke("get-productivity-records"),
  getConfig: () => ipcRenderer.invoke("get-config"),
  syncNow: () => ipcRenderer.invoke("sync-now"),
  getQueueStatus: () => ipcRenderer.invoke("get-queue-status"),
});

// Type definitions for exposed API
export interface ElectronAPI {
  getProductivityRecords: () => Promise<ProductivityRecord[]>;
  getConfig: () => Promise<Config>;
  syncNow: () => Promise<void>;
  getQueueStatus: () => Promise<{ size: number; oldestRetry: number }>;
}

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}
