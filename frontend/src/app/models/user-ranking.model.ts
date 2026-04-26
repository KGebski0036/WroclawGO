import { UserAchievement } from './achievement.model';
import { UserEquippedAvatarItem } from './avatar.model';

export interface LeaderboardUser {
  id: number;
  username: string;
  points: number;
  level: number;
  rank: number;
  is_liked: boolean;
  favorites_count: number;
  equipped_items: UserEquippedAvatarItem[];
}

export interface LeaderboardResponse {
  count: number;
  next: string | null;
  previous: string | null;
  results: LeaderboardUser[];
}

export interface PublicUserProfile {
  id: number;
  username: string;
  points: number;
  level: number;
  rank: number;
  is_liked: boolean;
  favorites_count: number;
  achievements_total: number;
  visited_total: number;
  equipped_items: UserEquippedAvatarItem[];
  achievements: UserAchievement[];
}

export interface FavoriteToggleResponse {
  username: string;
  is_liked: boolean;
  favorites_count: number;
}
