export interface ErrorDto {
  message: string;
  scope?: string;
  /** API `error_code` when the use case surfaces structured failures. */
  errorCode?: string;
  /** HTTP status when the use case surfaces transport failures without an i18n key. */
  httpStatus?: number;
}
