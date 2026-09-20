export function classifySession(openedAt: Date, timeZone: string): string {
  const hour = Number(
    new Intl.DateTimeFormat('en-GB', {
      hour: 'numeric',
      hour12: false,
      timeZone,
    }).format(openedAt),
  );
  if (hour >= 0 && hour < 8) return 'Asian';
  if (hour >= 8 && hour < 13) return 'London';
  if (hour >= 13 && hour < 16) return 'London / New York Overlap';
  if (hour >= 16 && hour < 22) return 'New York';
  return 'Other';
}

export function isJournalComplete(input: {
  strategyId?: string | null;
  primaryEmotion?: string | null;
  notes?: string | null;
  checklistCount?: number;
  checkedCount?: number;
}): boolean {
  const checklistOk =
    (input.checklistCount ?? 0) === 0 || (input.checkedCount ?? 0) > 0;
  return Boolean(
    input.strategyId &&
      input.primaryEmotion &&
      input.notes &&
      input.notes.trim().length > 0 &&
      checklistOk,
  );
}

export function moneyMath(left: string, right: string, op: 'minus' | 'plus') {
  const a = Number(left);
  const b = Number(right);
  const result = op === 'minus' ? a - b : a + b;
  return result.toFixed(2);
}

export function idOf(value: unknown): string {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value !== null) {
    const record = value as {
      id?: string;
      _id?: { toString(): string };
      toHexString?: () => string;
      toString?: () => string;
    };
    if (typeof record.toHexString === 'function') return record.toHexString();
    if (record.id) return record.id;
    if (record._id) return record._id.toString();
    if (typeof record.toString === 'function' && record.toString !== Object.prototype.toString) {
      return record.toString();
    }
  }
  return String(value);
}
