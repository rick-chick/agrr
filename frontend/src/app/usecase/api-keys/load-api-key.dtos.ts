export interface LoadApiKeyInputDto {
  // No input required; load uses current user / storage
}

export interface LoadApiKeyDataDto {
  apiKey: string | null;
}
