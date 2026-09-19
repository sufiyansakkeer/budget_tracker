import { StyleSheet, View } from 'react-native';
import { AppText } from '../../../components/AppText';
import { Card } from '../../../components/Card';
import { Icon } from '../../../components/Icon';
import type { ColorToken } from '../../../theme/colors';
import { useTheme } from '../../../theme/ThemeProvider';

interface StatTileProps {
  icon: string;
  label: string;
  value: string;
  tint?: ColorToken;
}

/** Compact metric tile for the dashboard's secondary figures. */
export function StatTile({ icon, label, value, tint = 'primary' }: StatTileProps) {
  const theme = useTheme();

  return (
    <Card style={styles.card}>
      <View style={styles.row}>
        <Icon name={icon} size={18} color={tint} />
        <AppText
          variant="caption"
          color="textSecondary"
          numberOfLines={1}
          style={[styles.label, { marginLeft: theme.spacing.xs }]}
        >
          {label}
        </AppText>
      </View>
      <AppText variant="subtitle" numberOfLines={1} style={{ marginTop: theme.spacing.xs }}>
        {value}
      </AppText>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { flex: 1 },
  label: { flex: 1 },
  row: { flexDirection: 'row', alignItems: 'center' },
});
