export interface WorkVarianceInitInputPort {
  execute(): void;
  applyFilters(filters: import('./work-variance-init.dtos').WorkVarianceInitPresentDto['filters']): void;
}
