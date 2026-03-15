import { useEffect, useState } from "react";
import "./index.css";

function App() {
  const [status, setStatus] = useState<"loading" | "active">("loading");
  const [queueStatus, setQueueStatus] = useState<{ size: number; oldestRetry: number } | null>(null);

  useEffect(() => {
    // Check if we're running in Electron
    if (window.electronAPI) {
      setStatus("active");

      // Load queue status every 5 seconds
      const loadStatus = async () => {
        try {
          const status = await window.electronAPI.getQueueStatus();
          setQueueStatus(status);
        } catch (error) {
          console.error("Failed to load queue status:", error);
        }
      };

      loadStatus();
      const interval = setInterval(loadStatus, 5000);

      return () => clearInterval(interval);
    }
  }, []);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 p-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-4">
          LifeLens Desktop Tracker
        </h1>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white">
                Status
              </h2>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                {status === "active" ? "✓ Tracking active" : "Loading..."}
              </p>
            </div>
            <button
              onClick={() => window.electronAPI.syncNow()}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              Sync Now
            </button>
          </div>

          {queueStatus && (
            <div className="border-t pt-4 mt-4">
              <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Queue Status
              </h3>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Queued records: <span className="font-mono">{queueStatus.size}</span>
              </div>
              {queueStatus.oldestRetry > 0 && (
                <div className="text-sm text-yellow-600 dark:text-yellow-400">
                  ⚠ Oldest retry count: {queueStatus.oldestRetry}
                </div>
              )}
            </div>
          )}

          <div className="border-t pt-4 mt-4">
            <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              What's Being Tracked
            </h3>
            <ul className="text-sm text-gray-600 dark:text-gray-400 space-y-1">
              <li>• Active application name and window title</li>
              <li>• Time spent in each app (categorized as work/study/leisure)</li>
              <li>• Synced to your home server every 5 minutes</li>
              <li>• Data queued locally if server is unavailable</li>
            </ul>
          </div>

          <div className="border-t pt-4 mt-4">
            <p className="text-xs text-gray-500 dark:text-gray-500">
              Running in background. Close window to minimize to system tray.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
