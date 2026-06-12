import AsyncStorage from '@react-native-async-storage/async-storage';

const KEYS = {
  profile: 'circles_profile',
  circles: 'circles_all',
  members: 'circles_members',
  shares:  (id: string) => `circles_shares_${id}`,
};

export type ReactionType = 'save' | 'fire' | 'curious';

export type JoinResult = 'ok' | 'pending' | 'already_member' | 'invalid_token' | 'not_found';

export interface Member {
  userId:      string;
  displayName: string;
  avatar:      string;
}

export interface PendingRequest {
  userId:      string;
  displayName: string;
  avatar:      string;
  requestedAt: number;
}

export interface Circle {
  id:              string;
  name:            string;
  emoji:           string;
  ownerId:         string;
  memberIds:       string[];
  inviteToken:     string;
  pendingRequests: PendingRequest[];
  createdAt:       number;
}

export interface Reaction {
  userId: string;
  type:   ReactionType;
}

export interface Comment {
  userId:      string;
  displayName: string;
  text:        string;
  timestamp:   number;
}

export interface StorePayload {
  id:       string;
  name:     string;
  address?: string;
}

export interface ProductPayload {
  id:          string;
  name:        string;
  brand?:      string;
  strainType?: 'Sativa' | 'Indica' | 'Hybrid';
}

export interface Share {
  id:        string;
  circleId:  string;
  sharerId:  string;
  type:      'store' | 'product';
  payload:   StorePayload | ProductPayload;
  note:      string;
  timestamp: number;
  reactions: Reaction[];
  comments:  Comment[];
}

function uuid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function generateToken(): string {
  return Math.random().toString(36).slice(2, 10).toUpperCase();
}

export function getInviteLink(circle: Circle): string {
  return `cannaguide://circles/join?id=${circle.id}&token=${circle.inviteToken}`;
}

export function parseInviteUrl(url: string): { circleId: string; token: string } | null {
  if (!url.includes('circles/join')) return null;
  try {
    const query = url.split('?')[1] ?? '';
    const params: Record<string, string> = {};
    query.split('&').forEach(p => {
      const [k, v] = p.split('=');
      if (k && v) params[k] = v;
    });
    if (!params.id || !params.token) return null;
    return { circleId: params.id, token: params.token };
  } catch {
    return null;
  }
}

// ── Profile ──────────────────────────────────────────────────────────────────

export async function getProfile(): Promise<Member | null> {
  const raw = await AsyncStorage.getItem(KEYS.profile);
  return raw ? JSON.parse(raw) : null;
}

export async function saveProfile(m: Member): Promise<void> {
  await AsyncStorage.setItem(KEYS.profile, JSON.stringify(m));
  await upsertMember(m);
}

export async function getOrCreateProfile(): Promise<Member> {
  const existing = await getProfile();
  if (existing) return existing;
  return { userId: uuid(), displayName: '', avatar: '🌿' };
}

// ── Members ───────────────────────────────────────────────────────────────────

export async function getAllMembers(): Promise<Record<string, Member>> {
  const raw = await AsyncStorage.getItem(KEYS.members);
  return raw ? JSON.parse(raw) : {};
}

export async function upsertMember(m: Member): Promise<void> {
  const all = await getAllMembers();
  all[m.userId] = m;
  await AsyncStorage.setItem(KEYS.members, JSON.stringify(all));
}

export async function createMember(displayName: string, avatar: string): Promise<Member> {
  const m: Member = { userId: uuid(), displayName, avatar };
  await upsertMember(m);
  return m;
}

// ── Circles ───────────────────────────────────────────────────────────────────

export async function getCircles(): Promise<Circle[]> {
  const raw = await AsyncStorage.getItem(KEYS.circles);
  const circles: any[] = raw ? JSON.parse(raw) : [];
  // Backfill any circles created before inviteToken/pendingRequests were added
  return circles.map(c => ({
    ...c,
    inviteToken:     c.inviteToken     ?? generateToken(),
    pendingRequests: c.pendingRequests ?? [],
  }));
}

export async function createCircle(
  name:    string,
  emoji:   string,
  owner:   Member,
  members: Member[],
): Promise<Circle> {
  const circles = await getCircles();
  const circle: Circle = {
    id:              uuid(),
    name,
    emoji,
    ownerId:         owner.userId,
    memberIds:       [owner.userId, ...members.map(m => m.userId)],
    inviteToken:     generateToken(),
    pendingRequests: [],
    createdAt:       Date.now(),
  };
  await AsyncStorage.setItem(KEYS.circles, JSON.stringify([...circles, circle]));
  return circle;
}

export async function requestToJoin(
  circleId:  string,
  token:     string,
  requester: Member,
): Promise<JoinResult> {
  const circles = await getCircles();
  const circle  = circles.find(c => c.id === circleId);
  if (!circle)                                              return 'not_found';
  if (circle.inviteToken !== token)                         return 'invalid_token';
  if (circle.memberIds.includes(requester.userId))          return 'already_member';
  if (circle.pendingRequests.some(r => r.userId === requester.userId)) return 'pending';

  const request: PendingRequest = {
    userId:      requester.userId,
    displayName: requester.displayName,
    avatar:      requester.avatar,
    requestedAt: Date.now(),
  };
  const updated = circles.map(c =>
    c.id === circleId
      ? { ...c, pendingRequests: [...c.pendingRequests, request] }
      : c,
  );
  await AsyncStorage.setItem(KEYS.circles, JSON.stringify(updated));
  return 'ok';
}

export async function approveRequest(circleId: string, userId: string): Promise<void> {
  const circles = await getCircles();
  const updated = circles.map(c => {
    if (c.id !== circleId) return c;
    return {
      ...c,
      memberIds:       [...c.memberIds, userId],
      pendingRequests: c.pendingRequests.filter(r => r.userId !== userId),
    };
  });
  await AsyncStorage.setItem(KEYS.circles, JSON.stringify(updated));
}

export async function declineRequest(circleId: string, userId: string): Promise<void> {
  const circles = await getCircles();
  const updated = circles.map(c => {
    if (c.id !== circleId) return c;
    return { ...c, pendingRequests: c.pendingRequests.filter(r => r.userId !== userId) };
  });
  await AsyncStorage.setItem(KEYS.circles, JSON.stringify(updated));
}

// ── Shares ────────────────────────────────────────────────────────────────────

export async function getShares(circleId: string): Promise<Share[]> {
  const raw = await AsyncStorage.getItem(KEYS.shares(circleId));
  const shares: Share[] = raw ? JSON.parse(raw) : [];
  return shares.sort((a, b) => b.timestamp - a.timestamp);
}

export async function addShare(
  data: Omit<Share, 'id' | 'reactions' | 'comments'>,
): Promise<Share> {
  const shares = await getShares(data.circleId);
  const share: Share = { ...data, id: uuid(), reactions: [], comments: [] };
  await AsyncStorage.setItem(KEYS.shares(data.circleId), JSON.stringify([share, ...shares]));
  return share;
}

export async function toggleReaction(
  circleId: string,
  shareId:  string,
  userId:   string,
  type:     ReactionType,
): Promise<Share[]> {
  const shares = await getShares(circleId);
  const updated = shares.map(s => {
    if (s.id !== shareId) return s;
    const exists = s.reactions.find(r => r.userId === userId && r.type === type);
    return {
      ...s,
      reactions: exists
        ? s.reactions.filter(r => !(r.userId === userId && r.type === type))
        : [...s.reactions, { userId, type }],
    };
  });
  await AsyncStorage.setItem(KEYS.shares(circleId), JSON.stringify(updated));
  return updated;
}

export async function addComment(
  circleId: string,
  shareId:  string,
  comment:  Comment,
): Promise<Share[]> {
  const shares = await getShares(circleId);
  const updated = shares.map(s =>
    s.id === shareId ? { ...s, comments: [...s.comments, comment] } : s,
  );
  await AsyncStorage.setItem(KEYS.shares(circleId), JSON.stringify(updated));
  return updated;
}
