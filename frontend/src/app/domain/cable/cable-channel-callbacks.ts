export interface CableChannelCallbacks<TMessage> {
  received: (message: TMessage) => void;
  disconnected?: () => void;
  rejected?: () => void;
}
