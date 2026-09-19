import {
  differenceInCalendarDays,
  endOfDay,
  format,
  isSameDay,
  isToday,
  isYesterday,
  startOfDay,
} from 'date-fns';

export { startOfDay, endOfDay, isSameDay, isToday, isYesterday };

/**
 * Whole calendar days between two dates, ignoring clock time.
 *
 * Budget math is day-based, so every span must be measured on calendar
 * boundaries — a 23-hour gap that crosses midnight is one day, not zero.
 */
export function calendarDaysBetween(from: Date, to: Date): number {
  return differenceInCalendarDays(startOfDay(to), startOfDay(from));
}

/** Inclusive day count of a period: 1 Aug → 3 Aug is 3 days. */
export function inclusiveDayCount(start: Date, end: Date): number {
  return calendarDaysBetween(start, end) + 1;
}

/** Whether `date` falls inside [start, end], compared by calendar day. */
export function isWithinPeriod(date: Date, start: Date, end: Date): boolean {
  const day = startOfDay(date).getTime();
  return day >= startOfDay(start).getTime() && day <= startOfDay(end).getTime();
}

export const formatDate = (date: Date) => format(date, 'd MMM yyyy');
export const formatShortDate = (date: Date) => format(date, 'd MMM');
export const formatTime = (date: Date) => format(date, 'h:mm a');
export const formatMonthYear = (date: Date) => format(date, 'MMMM yyyy');

/** Section headers in the expense list read "Today" / "Yesterday" / a date. */
export function formatRelativeDay(date: Date): string {
  if (isToday(date)) return 'Today';
  if (isYesterday(date)) return 'Yesterday';
  return formatDate(date);
}

/** First and last moment of the calendar month containing `date`. */
export function monthBounds(date: Date): { start: Date; end: Date } {
  const start = new Date(date.getFullYear(), date.getMonth(), 1);
  const end = endOfDay(new Date(date.getFullYear(), date.getMonth() + 1, 0));
  return { start, end };
}
