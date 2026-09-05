/**
 * Media cache settings store.
 *
 * Trước đây cấu hình này chỉ sống trong RAM của worker: Flutter đẩy sang một
 * lần lúc mở màn hình cài đặt, còn backend restart là quay về mặc định
 * 20GB/90 ngày cho tới khi có ai đó lưu lại cài đặt. Backend khởi động lại độc
 * lập với app (watchdog, cập nhật), nên giá trị phải nằm trên đĩa.
 */
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { dataRoot } from '../config.js';

const FILE = resolve(dataRoot, 'integrations', 'media-cache.json');

export interface MediaCacheSettings {
  maxGb: number;
  maxAgeDays: number;
}

export const DEFAULT_MEDIA_CACHE: MediaCacheSettings = { maxGb: 20, maxAgeDays: 90 };

/** Kẹp về khoảng hợp lệ; giá trị rác rơi về mặc định. */
export function sanitizeMediaCacheSettings(input: unknown): MediaCacheSettings {
  const data = (input ?? {}) as Record<string, unknown>;
  const clamp = (value: unknown, min: number, max: number, fallback: number): number => {
    const num = Number(value);
    if (!Number.isFinite(num)) return fallback;
    return Math.min(max, Math.max(min, Math.floor(num)));
  };
  return {
    maxGb: clamp(data.maxGb, 1, 1024, DEFAULT_MEDIA_CACHE.maxGb),
    maxAgeDays: clamp(data.maxAgeDays, 1, 3650, DEFAULT_MEDIA_CACHE.maxAgeDays),
  };
}

export function readMediaCacheSettings(file: string = FILE): MediaCacheSettings {
  if (!existsSync(file)) return { ...DEFAULT_MEDIA_CACHE };
  try {
    return sanitizeMediaCacheSettings(JSON.parse(readFileSync(file, 'utf-8')));
  } catch {
    return { ...DEFAULT_MEDIA_CACHE };
  }
}

export function writeMediaCacheSettings(
  input: unknown,
  file: string = FILE,
): MediaCacheSettings {
  const settings = sanitizeMediaCacheSettings(input);
  try {
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, JSON.stringify(settings, null, 2), 'utf-8');
  } catch (err) {
    console.error('[media-cache] Không lưu được cấu hình:', err);
  }
  return settings;
}
