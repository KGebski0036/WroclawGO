export interface Achievement {
  id: number;
  name: string;
  description: string;
  badge_path: string;
  points_reward: number;
}

export interface UserAchievement {
  id: number;
  achievement: Achievement;
  earned_at: string;
}
