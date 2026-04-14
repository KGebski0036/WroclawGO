import { SkinColor } from './skin-color.model';

export interface AuthUser {
  id: number;
  username: string;
  email: string;
  points: number;
  profile_picture: string | null;
  owned_skins: SkinColor[];
  selected_skin: SkinColor | null;
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