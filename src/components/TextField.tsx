import type { ComponentRef, Ref } from 'react';
import {
  StyleSheet,
  TextInput,
  View,
  type StyleProp,
  type TextInputProps,
  type ViewStyle,
} from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { AppText } from './AppText';

interface TextFieldProps extends TextInputProps {
  label?: string;
  /** Validation message. Its presence also switches the field to the error style. */
  error?: string;
  /** Hint shown below the field when there is no error. */
  hint?: string;
  /** Rendered inside the field, before the input — e.g. a currency symbol. */
  prefix?: string;
  containerStyle?: StyleProp<ViewStyle>;
  /**
   * React 19 passes `ref` as an ordinary prop, so no `forwardRef` wrapper is
   * needed. The instance type comes from `TextInput` itself — RN 0.87's
   * internal instance type is not the component type.
   */
  ref?: Ref<ComponentRef<typeof TextInput>>;
}

export function TextField({
  label,
  error,
  hint,
  prefix,
  containerStyle,
  style,
  ref,
  ...rest
}: TextFieldProps) {
  const theme = useTheme();
  const hasError = Boolean(error);

  return (
    <View style={containerStyle}>
      {label ? (
        <AppText
          variant="label"
          color="textSecondary"
          style={{ marginBottom: theme.spacing.xs }}
        >
          {label}
        </AppText>
      ) : null}

      <View
        style={[
          styles.field,
          {
            backgroundColor: theme.colors.surface,
            borderColor: hasError ? theme.colors.error : theme.colors.outline,
            borderRadius: theme.radius.sm,
            paddingHorizontal: theme.spacing.smd,
          },
        ]}
      >
        {prefix ? (
          <AppText
            variant="subtitle"
            color="textSecondary"
            style={styles.prefix}
          >
            {prefix}
          </AppText>
        ) : null}
        <TextInput
          ref={ref}
          placeholderTextColor={theme.colors.textTertiary}
          selectionColor={theme.colors.primary}
          accessibilityLabel={label}
          style={[
            styles.input,
            theme.typography.body,
            { color: theme.colors.textPrimary },
            style,
          ]}
          {...rest}
        />
      </View>

      {hasError ? (
        <AppText
          variant="caption"
          color="error"
          style={{ marginTop: theme.spacing.xs }}
        >
          {error}
        </AppText>
      ) : hint ? (
        <AppText
          variant="caption"
          color="textTertiary"
          style={{ marginTop: theme.spacing.xs }}
        >
          {hint}
        </AppText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    minHeight: 48,
  },
  prefix: { marginRight: 6 },
  input: { flex: 1, paddingVertical: 12 },
});
