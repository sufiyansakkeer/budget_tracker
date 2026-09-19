import { StyleSheet, View } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { AppText } from './AppText';
import { Button } from './Button';
import { Icon } from './Icon';

interface EmptyStateProps {
  icon: string;
  title: string;
  body?: string;
  actionLabel?: string;
  onAction?: () => void;
}

export function EmptyState({
  icon,
  title,
  body,
  actionLabel,
  onAction,
}: EmptyStateProps) {
  const theme = useTheme();

  return (
    <View style={[styles.root, { padding: theme.spacing.xl }]}>
      <View
        style={[
          styles.iconCircle,
          { backgroundColor: theme.colors.surfaceContainer },
        ]}
      >
        <Icon name={icon} size={32} color="textTertiary" />
      </View>
      <AppText variant="title" align="center" style={{ marginTop: theme.spacing.md }}>
        {title}
      </AppText>
      {body ? (
        <AppText
          variant="body"
          color="textSecondary"
          align="center"
          style={{ marginTop: theme.spacing.sm }}
        >
          {body}
        </AppText>
      ) : null}
      {actionLabel && onAction ? (
        <Button
          label={actionLabel}
          onPress={onAction}
          fullWidth={false}
          style={{ marginTop: theme.spacing.lg }}
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { alignItems: 'center', justifyContent: 'center', flexGrow: 1 },
  iconCircle: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
