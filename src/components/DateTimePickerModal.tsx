import { useMemo, useState } from 'react';
import { Modal, Pressable, StyleSheet, View } from 'react-native';
import {
  addMonths,
  format,
  isSameDay,
  isSameMonth,
  startOfMonth,
  startOfWeek,
} from 'date-fns';
import { useTheme } from '../theme/ThemeProvider';
import { AppText } from './AppText';
import { Button } from './Button';
import { Icon } from './Icon';

interface DateTimePickerModalProps {
  visible: boolean;
  value: Date;
  title: string;
  /** Show hour/minute steppers under the calendar. */
  withTime?: boolean;
  minimumDate?: Date;
  maximumDate?: Date;
  onConfirm: (date: Date) => void;
  onCancel: () => void;
  confirmLabel: string;
  cancelLabel: string;
}

const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const DAYS_IN_GRID = 42;

/**
 * Calendar picker built in JS rather than pulling in a native date-picker
 * module — it renders identically on both platforms and needs no pod install.
 */
export function DateTimePickerModal({
  visible,
  value,
  title,
  withTime = false,
  minimumDate,
  maximumDate,
  onConfirm,
  onCancel,
  confirmLabel,
  cancelLabel,
}: DateTimePickerModalProps) {
  const theme = useTheme();
  const [draft, setDraft] = useState(value);
  const [visibleMonth, setVisibleMonth] = useState(() => startOfMonth(value));

  // Re-seed the draft whenever the sheet is reopened with a different value.
  const [lastValue, setLastValue] = useState(value);
  if (visible && lastValue.getTime() !== value.getTime()) {
    setLastValue(value);
    setDraft(value);
    setVisibleMonth(startOfMonth(value));
  }

  const days = useMemo(() => {
    const gridStart = startOfWeek(startOfMonth(visibleMonth));
    return Array.from({ length: DAYS_IN_GRID }, (_, index) => {
      const date = new Date(gridStart);
      date.setDate(gridStart.getDate() + index);
      return date;
    });
  }, [visibleMonth]);

  const isOutOfRange = (date: Date) => {
    if (minimumDate && date < new Date(minimumDate.toDateString())) return true;
    if (maximumDate && date > new Date(maximumDate.toDateString())) return true;
    return false;
  };

  const selectDay = (date: Date) => {
    // Keep the time-of-day the draft already carries; only the day changes.
    const next = new Date(date);
    next.setHours(draft.getHours(), draft.getMinutes(), 0, 0);
    setDraft(next);
  };

  const shiftTime = (unit: 'hours' | 'minutes', delta: number) => {
    const next = new Date(draft);
    if (unit === 'hours') {
      next.setHours(next.getHours() + delta);
    } else {
      next.setMinutes(next.getMinutes() + delta);
    }
    setDraft(next);
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onCancel}
    >
      <Pressable
        style={[styles.backdrop, { backgroundColor: theme.colors.scrim }]}
        onPress={onCancel}
        accessibilityLabel={cancelLabel}
      >
        {/* Swallow taps inside the sheet so they do not dismiss it. */}
        <Pressable
          onPress={() => {}}
          style={[
            styles.sheet,
            {
              backgroundColor: theme.colors.surface,
              borderRadius: theme.radius.lg,
              padding: theme.spacing.md,
            },
          ]}
        >
          <AppText variant="title" align="center">
            {title}
          </AppText>

          <View style={[styles.monthRow, { marginVertical: theme.spacing.md }]}>
            <Pressable
              onPress={() => setVisibleMonth(addMonths(visibleMonth, -1))}
              hitSlop={12}
              accessibilityRole="button"
              accessibilityLabel="Previous month"
            >
              <Icon name="chevron-left" size={28} color="textSecondary" />
            </Pressable>
            <AppText variant="subtitle">
              {format(visibleMonth, 'MMMM yyyy')}
            </AppText>
            <Pressable
              onPress={() => setVisibleMonth(addMonths(visibleMonth, 1))}
              hitSlop={12}
              accessibilityRole="button"
              accessibilityLabel="Next month"
            >
              <Icon name="chevron-right" size={28} color="textSecondary" />
            </Pressable>
          </View>

          <View style={styles.weekRow}>
            {WEEKDAYS.map((day, index) => (
              <AppText
                key={`${day}-${index}`}
                variant="caption"
                color="textTertiary"
                align="center"
                style={styles.cell}
              >
                {day}
              </AppText>
            ))}
          </View>

          <View style={styles.grid}>
            {days.map(day => {
              const selected = isSameDay(day, draft);
              const disabled = isOutOfRange(day);
              const inMonth = isSameMonth(day, visibleMonth);

              return (
                <Pressable
                  key={day.toISOString()}
                  onPress={() => selectDay(day)}
                  disabled={disabled}
                  accessibilityRole="button"
                  accessibilityState={{ selected, disabled }}
                  accessibilityLabel={format(day, 'd MMMM yyyy')}
                  style={[
                    styles.cell,
                    styles.dayCell,
                    selected && {
                      backgroundColor: theme.colors.primary,
                      borderRadius: theme.radius.full,
                    },
                  ]}
                >
                  <AppText
                    variant="body"
                    align="center"
                    style={{
                      color: selected
                        ? theme.colors.onPrimary
                        : disabled
                          ? theme.colors.textTertiary
                          : inMonth
                            ? theme.colors.textPrimary
                            : theme.colors.textTertiary,
                      opacity: disabled ? 0.4 : 1,
                    }}
                  >
                    {day.getDate()}
                  </AppText>
                </Pressable>
              );
            })}
          </View>

          {withTime ? (
            <View style={[styles.timeRow, { marginTop: theme.spacing.md }]}>
              <TimeStepper
                label={format(draft, 'h a')}
                onIncrement={() => shiftTime('hours', 1)}
                onDecrement={() => shiftTime('hours', -1)}
              />
              <AppText variant="headline" color="textTertiary">
                :
              </AppText>
              <TimeStepper
                label={format(draft, 'mm')}
                onIncrement={() => shiftTime('minutes', 5)}
                onDecrement={() => shiftTime('minutes', -5)}
              />
            </View>
          ) : null}

          <View style={[styles.actions, { marginTop: theme.spacing.md }]}>
            <Button
              label={cancelLabel}
              variant="ghost"
              onPress={onCancel}
              style={styles.action}
            />
            <Button
              label={confirmLabel}
              onPress={() => onConfirm(draft)}
              style={styles.action}
            />
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

function TimeStepper({
  label,
  onIncrement,
  onDecrement,
}: {
  label: string;
  onIncrement: () => void;
  onDecrement: () => void;
}) {
  return (
    <View style={styles.stepper}>
      <Pressable onPress={onIncrement} hitSlop={8} accessibilityRole="button">
        <Icon name="keyboard-arrow-up" size={24} color="textSecondary" />
      </Pressable>
      <AppText variant="headline">{label}</AppText>
      <Pressable onPress={onDecrement} hitSlop={8} accessibilityRole="button">
        <Icon name="keyboard-arrow-down" size={24} color="textSecondary" />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  sheet: { width: '100%', maxWidth: 380 },
  monthRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  weekRow: { flexDirection: 'row' },
  grid: { flexDirection: 'row', flexWrap: 'wrap' },
  cell: { width: `${100 / 7}%` },
  dayCell: { aspectRatio: 1, alignItems: 'center', justifyContent: 'center' },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  stepper: { alignItems: 'center' },
  actions: { flexDirection: 'row', gap: 12 },
  action: { flex: 1 },
});
