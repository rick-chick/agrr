export interface Fertilize {
  id: number;
  name: string;
  n?: number | null;
  p?: number | null;
  k?: number | null;
  description?: string | null;
  package_size?: number | null;
  is_reference: boolean;
  region?: string | null;
}
