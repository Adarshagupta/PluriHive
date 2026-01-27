import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash } from 'crypto';
import { RouteEntity } from './route.entity';
import { CreateRouteDto } from './dto/create-route.dto';

type RoutePoint = { lat: number; lng: number };

@Injectable()
export class RoutesService {
  private readonly maxRoutePoints = 5000;
  private readonly simplifyEpsilonMeters = 12;

  constructor(
    @InjectRepository(RouteEntity)
    private routesRepository: Repository<RouteEntity>,
  ) {}

  async createRoute(userId: string, dto: CreateRouteDto): Promise<RouteEntity> {
    if (!dto.routePoints || dto.routePoints.length < 2) {
      throw new BadRequestException('Route requires at least 2 points');
    }

    const normalized = dto.routePoints.map((p) => ({
      lat: Number(p.lat),
      lng: Number(p.lng),
    }));

    if (normalized.length > this.maxRoutePoints) {
      throw new BadRequestException('Route too large');
    }

    const simplified = this.simplifyRoute(normalized, this.simplifyEpsilonMeters);
    const bounds = this.calculateBounds(simplified);
    const distanceKm = this.calculateDistanceMeters(simplified) / 1000;
    const h3Path = this.buildRouteTokens(simplified, 7);
    const routeHash = this.simHash(h3Path);

    const route = this.routesRepository.create({
      userId,
      name: dto.name.trim(),
      description: dto.description?.trim(),
      isPublic: dto.isPublic ?? false,
      routePoints: simplified,
      distanceKm,
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
      centerLat: bounds.centerLat,
      centerLng: bounds.centerLng,
      routeHash,
      h3Path,
    });

    return this.routesRepository.save(route);
  }

  async getUserRoutes(userId: string): Promise<RouteEntity[]> {
    return this.routesRepository.find({
      where: { userId },
      order: { updatedAt: 'DESC' },
    });
  }

  async getRouteById(userId: string, id: string): Promise<RouteEntity> {
    const route = await this.routesRepository.findOne({ where: { id } });
    if (!route) {
      throw new NotFoundException('Route not found');
    }
    if (!route.isPublic && route.userId !== userId) {
      throw new NotFoundException('Route not found');
    }
    return route;
  }

  async getPopularRoutesNear(
    lat: number,
    lng: number,
    radiusKm = 5,
    limit = 10,
  ): Promise<RouteEntity[]> {
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException('Invalid coordinates');
    }

    const radiusLat = radiusKm / 111;
    const radiusLng = radiusKm / (111 * Math.cos((lat * Math.PI) / 180));
    const minLat = lat - radiusLat;
    const maxLat = lat + radiusLat;
    const minLng = lng - radiusLng;
    const maxLng = lng + radiusLng;

    return this.routesRepository
      .createQueryBuilder('route')
      .where('route.isPublic = :isPublic', { isPublic: true })
      .andWhere('route.minLat <= :maxLat AND route.maxLat >= :minLat', {
        minLat,
        maxLat,
      })
      .andWhere('route.minLng <= :maxLng AND route.maxLng >= :minLng', {
        minLng,
        maxLng,
      })
      .orderBy('route.usageCount', 'DESC')
      .addOrderBy('route.lastUsedAt', 'DESC', 'NULLS LAST')
      .take(limit)
      .getMany();
  }

  async recordRouteUse(id: string): Promise<RouteEntity> {
    const route = await this.routesRepository.findOne({ where: { id } });
    if (!route) {
      throw new NotFoundException('Route not found');
    }
    route.usageCount = (route.usageCount || 0) + 1;
    route.lastUsedAt = new Date();
    return this.routesRepository.save(route);
  }

  private calculateBounds(points: RoutePoint[]) {
    let minLat = points[0].lat;
    let maxLat = points[0].lat;
    let minLng = points[0].lng;
    let maxLng = points[0].lng;

    for (const point of points) {
      minLat = Math.min(minLat, point.lat);
      maxLat = Math.max(maxLat, point.lat);
      minLng = Math.min(minLng, point.lng);
      maxLng = Math.max(maxLng, point.lng);
    }

    return {
      minLat,
      maxLat,
      minLng,
      maxLng,
      centerLat: (minLat + maxLat) / 2,
      centerLng: (minLng + maxLng) / 2,
    };
  }

  private calculateDistanceMeters(points: RoutePoint[]): number {
    if (points.length < 2) return 0;
    let total = 0;
    for (let i = 1; i < points.length; i++) {
      total += this.haversineMeters(points[i - 1], points[i]);
    }
    return total;
  }

  private haversineMeters(a: RoutePoint, b: RoutePoint): number {
    const R = 6371000;
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(b.lat - a.lat);
    const dLng = toRad(b.lng - a.lng);
    const lat1 = toRad(a.lat);
    const lat2 = toRad(b.lat);

    const h =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * R * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  }

  private simplifyRoute(points: RoutePoint[], epsilonMeters: number): RoutePoint[] {
    if (points.length < 3) return points;

    const first = points[0];
    const last = points[points.length - 1];
    let maxDist = 0;
    let index = 0;

    for (let i = 1; i < points.length - 1; i++) {
      const dist = this.distanceToSegmentMeters(points[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > epsilonMeters) {
      const left = this.simplifyRoute(points.slice(0, index + 1), epsilonMeters);
      const right = this.simplifyRoute(points.slice(index), epsilonMeters);
      return left.slice(0, -1).concat(right);
    }

    return [first, last];
  }

  private distanceToSegmentMeters(
    point: RoutePoint,
    start: RoutePoint,
    end: RoutePoint,
  ): number {
    const toXY = (p: RoutePoint, ref: RoutePoint) => {
      const R = 6371000;
      const x =
        ((p.lng - ref.lng) * Math.PI) / 180 * Math.cos((ref.lat * Math.PI) / 180) * R;
      const y = ((p.lat - ref.lat) * Math.PI) / 180 * R;
      return { x, y };
    };

    const ref = { lat: (start.lat + end.lat) / 2, lng: (start.lng + end.lng) / 2 };
    const s = toXY(start, ref);
    const e = toXY(end, ref);
    const p = toXY(point, ref);

    const dx = e.x - s.x;
    const dy = e.y - s.y;
    if (dx === 0 && dy === 0) {
      return Math.hypot(p.x - s.x, p.y - s.y);
    }

    const t = ((p.x - s.x) * dx + (p.y - s.y) * dy) / (dx * dx + dy * dy);
    const clamped = Math.max(0, Math.min(1, t));
    const projX = s.x + clamped * dx;
    const projY = s.y + clamped * dy;
    return Math.hypot(p.x - projX, p.y - projY);
  }

  private buildRouteTokens(points: RoutePoint[], precision: number): string[] {
    const tokens: string[] = [];
    let lastToken = '';
    for (const point of points) {
      const token = this.encodeGeohash(point.lat, point.lng, precision);
      if (token && token !== lastToken) {
        tokens.push(token);
        lastToken = token;
      }
    }
    return tokens;
  }

  private encodeGeohash(latitude: number, longitude: number, precision: number): string {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    let latMin = -90.0;
    let latMax = 90.0;
    let lonMin = -180.0;
    let lonMax = 180.0;
    let hash = '';
    let bit = 0;
    let ch = 0;
    let even = true;

    while (hash.length < precision) {
      if (even) {
        const mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          ch = (ch << 1) + 1;
          lonMin = mid;
        } else {
          ch = (ch << 1) + 0;
          lonMax = mid;
        }
      } else {
        const mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch = (ch << 1) + 1;
          latMin = mid;
        } else {
          ch = (ch << 1) + 0;
          latMax = mid;
        }
      }

      even = !even;
      bit++;

      if (bit === 5) {
        hash += base32[ch];
        bit = 0;
        ch = 0;
      }
    }

    return hash;
  }

  private simHash(tokens: string[]): string {
    if (tokens.length === 0) {
      return '0000000000000000';
    }

    const bits = new Array(64).fill(0);
    for (const token of tokens) {
      const hash = createHash('sha1').update(token).digest();
      let value = 0n;
      for (let i = 0; i < 8; i++) {
        value = (value << 8n) | BigInt(hash[i]);
      }
      for (let i = 0; i < 64; i++) {
        const bit = (value >> BigInt(i)) & 1n;
        bits[i] += bit === 1n ? 1 : -1;
      }
    }

    let result = 0n;
    for (let i = 0; i < 64; i++) {
      if (bits[i] > 0) {
        result |= 1n << BigInt(i);
      }
    }
    return result.toString(16).padStart(16, '0');
  }
}
