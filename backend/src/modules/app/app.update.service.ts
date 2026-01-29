import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type UpdateInfo = {
  version: string;
  min_version?: string;
  force_update: boolean;
  download_url?: string;
  release_notes?: string;
};

@Injectable()
export class AppUpdateService {
  constructor(private readonly config: ConfigService) {}

  getUpdateInfo(platform: string, currentVersion?: string): UpdateInfo {
    const key = platform.toUpperCase();
    const latest =
      this.config.get<string>(`APP_LATEST_VERSION_${key}`) ??
      this.config.get<string>('APP_LATEST_VERSION') ??
      '1.0.0';
    const minVersion =
      this.config.get<string>(`APP_MIN_VERSION_${key}`) ??
      this.config.get<string>('APP_MIN_VERSION') ??
      undefined;
    const downloadUrl =
      this.config.get<string>(`APP_DOWNLOAD_URL_${key}`) ??
      this.config.get<string>('APP_DOWNLOAD_URL') ??
      undefined;
    const releaseNotes =
      this.config.get<string>(`APP_RELEASE_NOTES_${key}`) ??
      this.config.get<string>('APP_RELEASE_NOTES') ??
      '';

    const forceUpdate =
      minVersion != null &&
      currentVersion != null &&
      this.isUpdateAvailable(currentVersion, minVersion);

    return {
      version: latest,
      min_version: minVersion,
      force_update: forceUpdate,
      download_url: downloadUrl,
      release_notes: releaseNotes,
    };
  }

  private isUpdateAvailable(current: string, latest: string): boolean {
    const currentParts = current.split('.').map((p) => parseInt(p, 10));
    const latestParts = latest.split('.').map((p) => parseInt(p, 10));
    for (let i = 0; i < Math.max(currentParts.length, latestParts.length); i += 1) {
      const currentPart = currentParts[i] ?? 0;
      const latestPart = latestParts[i] ?? 0;
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }
}
