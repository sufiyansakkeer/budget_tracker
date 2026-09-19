import { Alert } from 'react-native';

interface ConfirmOptions {
  title: string;
  message?: string;
  confirmLabel: string;
  cancelLabel: string;
  destructive?: boolean;
}

/**
 * Promise-wrapped native confirm dialog.
 *
 * Returning a promise lets callers `await confirm(...)` inside an async
 * handler instead of threading the decision through component state.
 */
export function confirm(options: ConfirmOptions): Promise<boolean> {
  return new Promise(resolve => {
    Alert.alert(
      options.title,
      options.message,
      [
        {
          text: options.cancelLabel,
          style: 'cancel',
          onPress: () => resolve(false),
        },
        {
          text: options.confirmLabel,
          style: options.destructive ? 'destructive' : 'default',
          onPress: () => resolve(true),
        },
      ],
      { cancelable: true, onDismiss: () => resolve(false) },
    );
  });
}
