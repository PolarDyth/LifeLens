import { contextBridge, ipcRenderer } from "electron";
contextBridge.exposeInMainProcess("electronAPI", {
  getProductivityRecords: () => ipcRenderer.invoke("get-productivity-records"),
  getConfig: () => ipcRenderer.invoke("get-config"),
  syncNow: () => ipcRenderer.invoke("sync-now"),
  getQueueStatus: () => ipcRenderer.invoke("get-queue-status")
});
