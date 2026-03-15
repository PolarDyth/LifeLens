import axios from "axios";
import type { ProductivityRecord, QueueItem, Config } from "@shared/types";
import os from "os";

/**
 * Sync service - batches productivity data and uploads to server
 */
export class SyncService {
  private queue: QueueItem[] = [];
  private config: Config;
  private syncInterval: NodeJS.Timeout | null = null;
  private retryTimeout: NodeJS.Timeout | null = null;
  private readonly MAX_QUEUE_SIZE = 10000;
  private readonly MAX_RETRY_ATTEMPTS = 10;
  private isSyncing = false;

  // Exponential backoff configuration
  private readonly BASE_DELAY_MS = 60000; // 1 minute
  private readonly MAX_DELAY_MS = 3600000; // 1 hour

  constructor(config: Config) {
    this.config = config;
  }

  /**
   * Start periodic sync
   */
  start(intervalMinutes: number = 5): void {
    console.log(`Starting sync service - uploading every ${intervalMinutes} minutes`);

    // Immediate sync on start
    this.attemptSync();

    // Periodic sync
    this.syncInterval = setInterval(() => {
      this.attemptSync();
    }, intervalMinutes * 60 * 1000);
  }

  /**
   * Stop syncing
   */
  stop(): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
    if (this.retryTimeout) {
      clearTimeout(this.retryTimeout);
      this.retryTimeout = null;
    }
  }

  /**
   * Add productivity record to sync queue
   */
  addRecord(record: ProductivityRecord): void {
    // Generate simple unique ID
    const id = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    const item: QueueItem = {
      id,
      type: "productivity",
      data: [record],
      timestamp: new Date(),
      retryCount: 0,
    };

    this.queue.push(item);

    // Prevent unlimited queue growth
    if (this.queue.length > this.MAX_QUEUE_SIZE) {
      this.queue.shift(); // Remove oldest item
      console.warn("Queue full, dropped oldest record");
    }

    // Try to sync immediately if we're not already syncing
    if (!this.isSyncing) {
      this.attemptSync();
    }
  }

  /**
   * Attempt sync with retry logic
   */
  private async attemptSync(): Promise<void> {
    if (this.isSyncing || this.queue.length === 0) {
      return;
    }

    await this.sync();
  }

  /**
   * Calculate exponential backoff delay
   */
  private calculateBackoffDelay(retryCount: number): number {
    const delay = this.BASE_DELAY_MS * Math.pow(2, retryCount);
    return Math.min(delay, this.MAX_DELAY_MS);
  }

  /**
   * Sync queued data to server with retry logic
   */
  private async sync(): Promise<void> {
    if (this.queue.length === 0) {
      return;
    }

    this.isSyncing = true;

    // Filter items that haven't exceeded max retry attempts
    const retryableItems = this.queue.filter((item) => item.retryCount < this.MAX_RETRY_ATTEMPTS);

    if (retryableItems.length === 0) {
      console.error("All queue items exceeded max retry attempts. Clearing queue.");
      this.queue = [];
      this.isSyncing = false;
      return;
    }

    // Calculate backoff delay based on oldest retry count
    const maxRetryCount = Math.max(...retryableItems.map((i) => i.retryCount));
    const backoffDelay = this.calculateBackoffDelay(maxRetryCount);

    // If we've retried before, add delay
    if (maxRetryCount > 0) {
      console.log(`Backoff: waiting ${backoffDelay / 1000}s before retry attempt ${maxRetryCount + 1}`);
      await new Promise((resolve) => setTimeout(resolve, backoffDelay));
    }

    console.log(`Syncing ${retryableItems.length} queued items to server...`);

    // Batch all records into a single request
    const allRecords = retryableItems.flatMap((item) => item.data);

    try {
      const response = await axios.post(
        `${this.config.serverUrl}/api/v1/ingest/productivity/batch`,
        {
          records: allRecords.map((record) => ({
            device_id: this.config.device_id,
            app_name: record.app_name,
            window_title: record.window_title,
            category: record.category,
            duration_seconds: record.duration_seconds,
            input_activity: record.input_activity,
            timestamp: record.timestamp.toISOString(),
            platform: this.config.platform,
          })),
        },
        {
          headers: {
            "Content-Type": "application/json",
            "X-API-Key": this.config.apiKey,
          },
          timeout: 30000, // 30 seconds
        }
      );

      if (response.status === 201) {
        console.log(`✓ Synced ${allRecords.length} records successfully`);

        // Remove successfully synced items
        this.queue = this.queue.filter((item) =>
          !retryableItems.some((retryable) => retryable.id === item.id)
        );

        // Reset retry timeout on success
        if (this.retryTimeout) {
          clearTimeout(this.retryTimeout);
          this.retryTimeout = null;
        }
      } else {
        throw new Error(`Unexpected response: ${response.status}`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorCode = error instanceof Error && 'code' in error ? (error as any).code : 'UNKNOWN';

      console.error(`Sync failed (${errorCode}):`, errorMessage);

      // Increment retry count for failed items
      retryableItems.forEach((item) => {
        item.retryCount++;
        item.lastError = errorMessage;
      });

      // Log queue status for debugging
      console.error(`Queue status: ${this.queue.length} items, max retry: ${maxRetryCount}`);

      // Schedule next retry with backoff
      const nextDelay = this.calculateBackoffDelay(maxRetryCount + 1);
      this.retryTimeout = setTimeout(() => {
        this.attemptSync();
      }, nextDelay);
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Manual sync trigger (flushes queue immediately)
   */
  async manualSync(): Promise<void> {
    console.log("Manual sync triggered - flushing queue");

    // Reset retry counts for manual sync
    this.queue.forEach((item) => {
      if (item.retryCount > 0) {
        console.log(`Resetting retry count for item ${item.id} (was ${item.retryCount})`);
        item.retryCount = 0;
      }
    });

    // Cancel any pending retry timeout
    if (this.retryTimeout) {
      clearTimeout(this.retryTimeout);
      this.retryTimeout = null;
    }

    await this.sync();
  }

  /**
   * Get queue status
   */
  getQueueStatus(): {
    size: number;
    oldestRetry: number;
    lastError: string | null;
    isSyncing: boolean;
  } {
    const lastError = this.queue.length > 0
      ? this.queue.find((i) => i.lastError)?.lastError || null
      : null;

    return {
      size: this.queue.length,
      oldestRetry: this.queue.length > 0 ? Math.max(...this.queue.map((i) => i.retryCount)) : 0,
      lastError,
      isSyncing: this.isSyncing,
    };
  }
}

/**
 * Generate or load device ID
 */
export function getDeviceId(): string {
  // In production, would store in electron-store
  return `desktop-${os.platform()}-${os.hostname()}`;
}

/**
 * Load or create config
 */
export function loadConfig(): Config {
  // In production, would load from electron-store or config file
  return {
    serverUrl: process.env.LIFLENS_SERVER_URL || "http://localhost:8000",
    apiKey: process.env.LIFLENS_API_KEY || "test-key",
    device_id: getDeviceId(),
    trackingIntervalSeconds: 5,
    uploadIntervalMinutes: 5,
    platform: os.platform() as "macos" | "win32" | "linux",
  };
}

// Singleton instance
let syncInstance: SyncService | null = null;

export function getSyncService(): SyncService {
  if (!syncInstance) {
    const config = loadConfig();
    syncInstance = new SyncService(config);
  }
  return syncInstance;
}
