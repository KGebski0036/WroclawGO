export interface AuthUser {
  id: number;
  username: string;
  email: string;
  points: number;
  profile_picture: string | null;
  equipped_items?: AuthEquippedItem[];
}

export interface AuthEquippedItem {
  id: number;
  slot: string;
  updated_at: string;
  item: {
    id: number;
    tag: string;
    name: string;
    svg_path: string;
    cost: number;
    is_default: boolean;
  };
}

export interface AuthResponse {
  user: AuthUser;
  access: string;
  refresh: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  username: string;
  email: string;
  password: string;
  password_confirm: string;
}