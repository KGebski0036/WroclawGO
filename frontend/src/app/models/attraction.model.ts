export interface AttractionProperties {
  id: number;
  name: string;
  description: string;
  category: string;
  points_reward: number;
}

export interface AttractionGeometry {
  type: 'Point';
  coordinates: [number, number]; // [lng, lat]
}

export interface AttractionFeature {
  type: 'Feature';
  geometry: AttractionGeometry;
  properties: AttractionProperties;
}

export interface AttractionGeoJSON {
  type: 'FeatureCollection';
  features: AttractionFeature[];
}

export interface VisitedAttraction {
  id: number;
  attraction: AttractionProperties;
  visited_at: string;
}
