export interface AvatarItem {
  id: number;
  tag: string;
  name: string;
  svg_path: string;
  cost: number;
  is_default: boolean;
}

export interface UserAvatarItem {
  id: number;
  item: AvatarItem;
  unlocked_at: string;
}

export interface UserEquippedAvatarItem {
  id: number;
  slot: string;
  item: AvatarItem;
  updated_at: string;
}