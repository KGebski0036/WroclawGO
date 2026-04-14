export interface SkinColor {
  id: number;
  name: string;
  color_value: string;
  price: number;
  image_file_name?: string;
  imageFileName?: string; // Fallback field name
  is_premium?: boolean;
}
