import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { apiClient } from './api';

describe('APIClient', () => {
  let mockFetch: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockFetch = vi.fn();
    global.fetch = mockFetch;
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('healthCheck', () => {
    it('returns status and version', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ status: 'ok', version: '0.1.0' }),
      });

      const result = await apiClient.healthCheck();

      expect(mockFetch).toHaveBeenCalledWith(
        'http://localhost:8000/health',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
            'X-API-Key': 'test-key',
          }),
        })
      );

      expect(result).toEqual({ status: 'ok', version: '0.1.0' });
    });

    it('throws error on non-OK response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
      });

      await expect(apiClient.healthCheck()).rejects.toThrow('API error: 500 Internal Server Error');
    });
  });

  describe('ingestHealth', () => {
    it('posts health data successfully', async () => {
      const healthData = {
        device_id: 'test-device',
        data_type: 'steps',
        value: 1000,
        unit: 'count',
        timestamp: '2024-01-01T00:00:00Z',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ message: 'Health data received', record_count: 1 }),
      });

      const result = await apiClient.ingestHealth(healthData);

      expect(mockFetch).toHaveBeenCalledWith(
        'http://localhost:8000/api/v1/ingest/health',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(healthData),
        })
      );

      expect(result).toEqual({ message: 'Health data received', record_count: 1 });
    });

    it('throws error on 422 validation error', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 422,
        statusText: 'Unprocessable Entity',
      });

      await expect(
        apiClient.ingestHealth({
          device_id: 'test',
          data_type: 'steps',
          value: 0,
          unit: 'count',
          timestamp: '2024-01-01T00:00:00Z',
        })
      ).rejects.toThrow('API error: 422 Unprocessable Entity');
    });
  });

  describe('ingestProductivity', () => {
    it('posts productivity data successfully', async () => {
      const productivityData = {
        device_id: 'test-device',
        app_name: 'TestApp',
        duration_seconds: 3600,
        timestamp: '2024-01-01T00:00:00Z',
        platform: 'macos',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ message: 'Productivity data received', record_count: 1 }),
      });

      const result = await apiClient.ingestProductivity(productivityData);

      expect(result).toEqual({ message: 'Productivity data received', record_count: 1 });
    });
  });

  describe('ingestLocation', () => {
    it('posts location data successfully', async () => {
      const locationData = {
        device_id: 'test-device',
        location_type: 'gps',
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: '2024-01-01T00:00:00Z',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ message: 'Location data received', record_count: 1 }),
      });

      const result = await apiClient.ingestLocation(locationData);

      expect(result).toEqual({ message: 'Location data received', record_count: 1 });
    });
  });

  describe('retry logic', () => {
    it('throws error on network failure', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      // Current implementation doesn't have retry logic - it throws immediately
      await expect(apiClient.healthCheck()).rejects.toThrow('Network error');
    });
  });

  describe('query endpoints', () => {
    it('fetches health summary for today', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          device_id: 'test-device',
          date: '2024-01-01',
          steps: 10000,
          avg_heart_rate: 72,
          min_heart_rate: 60,
          max_heart_rate: 85,
          sleep_duration_hours: 7.5,
          active_calories: 500,
          distance_km: 5.2,
        }),
      });

      const result = await apiClient.getHealthToday('test-device');

      expect(mockFetch).toHaveBeenCalledWith(
        'http://localhost:8000/api/v1/query/health/today?device_id=test-device',
        expect.objectContaining({
          headers: expect.objectContaining({
            'X-API-Key': 'test-key',
          }),
        })
      );

      expect(result.steps).toBe(10000);
      expect(result.avg_heart_rate).toBe(72);
    });

    it('fetches productivity breakdown for today', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          device_id: 'test-device',
          date: '2024-01-01',
          work_seconds: 7200,
          study_seconds: 3600,
          leisure_seconds: 1800,
          communication_seconds: 600,
          other_seconds: 300,
          total_seconds: 13500,
        }),
      });

      const result = await apiClient.getProductivityToday('test-device');

      expect(result.work_seconds).toBe(7200);
      expect(result.study_seconds).toBe(3600);
      expect(result.total_seconds).toBe(13500);
    });

    it('fetches recent locations', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => [
          {
            device_id: 'test-device',
            timestamp: '2024-01-01T10:00:00Z',
            latitude: 37.7749,
            longitude: -122.4194,
            location_type: 'gps',
            place_name: null,
          },
          {
            device_id: 'test-device',
            timestamp: '2024-01-01T09:00:00Z',
            latitude: 37.7749,
            longitude: -122.4094,
            location_type: 'visit',
            place_name: 'Coffee Shop',
          },
        ],
      });

      const result = await apiClient.getRecentLocations('test-device', 100);

      expect(result).toHaveLength(2);
      expect(result[0].location_type).toBe('gps');
      expect(result[1].place_name).toBe('Coffee Shop');
    });
  });
});
