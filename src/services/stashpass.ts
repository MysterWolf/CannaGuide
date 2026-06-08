import * as SecureStore from 'expo-secure-store';

export const STASHPASS_BASE_URL = 'https://stashpass-api-production.up.railway.app';

const KEYS = {
  accessToken:  'stashpass_access_token',
  refreshToken: 'stashpass_refresh_token',
  userId:       'stashpass_user_id',
} as const;

// ─── Token storage ────────────────────────────────────────────────────────────

export async function saveTokens(
  accessToken: string,
  refreshToken: string,
  userId: string,
): Promise<void> {
  await SecureStore.setItemAsync(KEYS.accessToken,  accessToken);
  await SecureStore.setItemAsync(KEYS.refreshToken, refreshToken);
  await SecureStore.setItemAsync(KEYS.userId,       userId);
}

export async function getStoredTokens(): Promise<{
  accessToken: string;
  refreshToken: string;
  userId: string;
} | null> {
  const [access, refresh, userId] = await Promise.all([
    SecureStore.getItemAsync(KEYS.accessToken),
    SecureStore.getItemAsync(KEYS.refreshToken),
    SecureStore.getItemAsync(KEYS.userId),
  ]);
  if (!access || !refresh || !userId) return null;
  return { accessToken: access, refreshToken: refresh, userId };
}

export async function clearTokens(): Promise<void> {
  await Promise.all([
    SecureStore.deleteItemAsync(KEYS.accessToken),
    SecureStore.deleteItemAsync(KEYS.refreshToken),
    SecureStore.deleteItemAsync(KEYS.userId),
  ]);
}

// ─── Internal fetch wrapper with auto-refresh ─────────────────────────────────

async function tryRefresh(refreshToken: string): Promise<string | null> {
  try {
    const res = await fetch(`${STASHPASS_BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    // Persist new token pair; userId doesn't change on refresh
    const stored = await getStoredTokens();
    if (stored) {
      await saveTokens(data.access_token, data.refresh_token, stored.userId);
    }
    return data.access_token;
  } catch {
    return null;
  }
}

async function apiRequest(
  path: string,
  options: RequestInit = {},
  retry = true,
): Promise<Response> {
  const stored = await getStoredTokens();
  if (!stored) throw new StashPassAuthError('Not authenticated');

  const res = await fetch(`${STASHPASS_BASE_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${stored.accessToken}`,
      ...(options.headers ?? {}),
    },
  });

  if (res.status === 401 && retry) {
    const newAccess = await tryRefresh(stored.refreshToken);
    if (!newAccess) {
      await clearTokens();
      throw new StashPassAuthError('Session expired — please reconnect in Settings');
    }
    return apiRequest(path, options, false);
  }

  return res;
}

export class StashPassAuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'StashPassAuthError';
  }
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

export async function requestOtp(contact: string): Promise<void> {
  const isPhone = /^\+?[\d\s\-()]{7,}$/.test(contact.replace(/\s/g, ''));
  const body = isPhone ? { phone: contact } : { email: contact };
  const res = await fetch(`${STASHPASS_BASE_URL}/auth/otp/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as any).error ?? 'Failed to send OTP');
  }
}

export async function verifyOtp(
  contact: string,
  otp: string,
): Promise<{ userId: string; accessToken: string; refreshToken: string }> {
  const isPhone = /^\+?[\d\s\-()]{7,}$/.test(contact.replace(/\s/g, ''));
  const body = isPhone
    ? { phone: contact, otp }
    : { email: contact, otp };

  const res = await fetch(`${STASHPASS_BASE_URL}/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as any).error ?? 'Invalid OTP');
  }
  const data = await res.json();
  await saveTokens(data.access_token, data.refresh_token, data.user.id);
  return {
    userId:       data.user.id,
    accessToken:  data.access_token,
    refreshToken: data.refresh_token,
  };
}

export async function logout(): Promise<void> {
  const stored = await getStoredTokens();
  if (!stored) return;
  try {
    await apiRequest('/auth/logout', {
      method: 'POST',
      body: JSON.stringify({ refresh_token: stored.refreshToken }),
    });
  } catch {
    // best-effort; clear locally regardless
  }
  await clearTokens();
}

// ─── Wallet ───────────────────────────────────────────────────────────────────

export interface BalanceResult {
  balance_points: number;
  lifetime_earned: number;
  lifetime_spent: number;
  dollar_value: number;
}

export async function getBalance(operatorId: string): Promise<BalanceResult> {
  const res = await apiRequest(
    `/wallet/balance?operator_id=${encodeURIComponent(operatorId)}`,
  );
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as any).error ?? 'Failed to fetch balance');
  }
  return res.json();
}

export interface EarnResult {
  transaction: {
    id: string;
    points_delta: number;
    balance_after: number;
    type: string;
    created_at: string;
  };
}

export async function earn(params: {
  operatorId: string;
  locationId?: string;
  amountDollars?: number;
  note?: string;
}): Promise<EarnResult> {
  const { operatorId, locationId, amountDollars = 1.0, note = 'check-in' } = params;
  const res = await apiRequest('/wallet/earn', {
    method: 'POST',
    body: JSON.stringify({
      operator_id:    operatorId,
      location_id:    locationId,
      amount_dollars: amountDollars,
      note,
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as any).error ?? 'Check-in failed');
  }
  return res.json();
}

export interface RedeemResult {
  transaction: { id: string; points_delta: number; balance_after: number };
  dollar_value: number;
}

export async function redeem(params: {
  operatorId: string;
  points: number;
  note?: string;
}): Promise<RedeemResult> {
  const res = await apiRequest('/wallet/redeem', {
    method: 'POST',
    body: JSON.stringify({
      operator_id: params.operatorId,
      points:      params.points,
      note:        params.note,
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as any).error ?? 'Redeem failed');
  }
  return res.json();
}
