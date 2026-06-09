/** Smooth-scroll to a document element by id (in-page anchor navigation). */
export function scrollToElementId(
  id: string,
  options: ScrollIntoViewOptions = { behavior: 'smooth', block: 'start' }
): void {
  if (typeof document === 'undefined') {
    return;
  }
  document.getElementById(id)?.scrollIntoView(options);
}
