import React, { useState, useCallback, useRef } from 'react';
import {
  View, Text, Pressable, StyleSheet, FlatList,
  TextInput, StatusBar, KeyboardAvoidingView, Platform,
  Modal, Share as RNShare, ScrollView,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect, useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp, RouteProp } from '@react-navigation/native-stack';
import QRCode from 'react-native-qrcode-svg';
import { C } from '../../theme/colors';
import {
  getCircles, getShares, getAllMembers, getProfile,
  toggleReaction, addComment, approveRequest, declineRequest,
  getInviteLink,
  Circle, Share, Member, ReactionType, Comment, PendingRequest,
} from '../../services/circles';
import type { CirclesStackParamList } from './CirclesNavigator';

type Nav   = NativeStackNavigationProp<CirclesStackParamList, 'CircleDetail'>;
type Route = RouteProp<CirclesStackParamList, 'CircleDetail'>;

function formatTime(ts: number): string {
  const diff = Date.now() - ts;
  if (diff < 60000)    return 'just now';
  if (diff < 3600000)  return `${Math.floor(diff / 60000)}m ago`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
  return `${Math.floor(diff / 86400000)}d ago`;
}

const REACTIONS: { type: ReactionType; emoji: string }[] = [
  { type: 'save',    emoji: '🔖' },
  { type: 'fire',    emoji: '🔥' },
  { type: 'curious', emoji: '🤔' },
];

function TypeBadge({ type }: { type: 'store' | 'product' }) {
  const isStore = type === 'store';
  return (
    <View style={[badge.root, { backgroundColor: isStore ? C.circlesLt : C.accentLight }]}>
      <Text style={[badge.text, { color: isStore ? C.circles : C.accent }]}>
        {isStore ? 'Discovery' : 'Product'}
      </Text>
    </View>
  );
}
const badge = StyleSheet.create({
  root: { alignSelf: 'flex-start', borderRadius: 6, paddingVertical: 3, paddingHorizontal: 8, marginBottom: 10 },
  text: { fontSize: 11, fontWeight: '700', letterSpacing: 0.5 },
});

function PayloadCard({ share }: { share: Share }) {
  const p = share.payload as any;
  return (
    <View style={pc.root}>
      <Text style={pc.name} numberOfLines={1}>{p.name ?? '—'}</Text>
      {(p.address || p.brand || p.strainType) && (
        <Text style={pc.sub} numberOfLines={1}>
          {p.address ?? [p.brand, p.strainType].filter(Boolean).join(' · ')}
        </Text>
      )}
    </View>
  );
}
const pc = StyleSheet.create({
  root: { backgroundColor: C.bg, borderWidth: 1, borderColor: C.border, borderRadius: 10, padding: 12, marginBottom: 10 },
  name: { fontSize: 14, fontWeight: '600', color: C.text },
  sub:  { fontSize: 12, color: C.muted, marginTop: 3 },
});

interface ShareCardProps {
  share:      Share;
  members:    Record<string, Member>;
  myUserId:   string;
  expanded:   boolean;
  onExpand:   () => void;
  onReaction: (type: ReactionType) => void;
  onComment:  (text: string) => void;
}

function ShareCard({ share, members, myUserId, expanded, onExpand, onReaction, onComment }: ShareCardProps) {
  const [commentText, setCommentText] = useState('');
  const sharer = members[share.sharerId];

  const submitComment = () => {
    const t = commentText.trim();
    if (!t) return;
    onComment(t);
    setCommentText('');
  };

  return (
    <View style={sc.root}>
      <View style={sc.sharerRow}>
        <Text style={sc.avatar}>{sharer?.avatar ?? '🌿'}</Text>
        <View style={{ flex: 1 }}>
          <Text style={sc.sharerName}>{sharer?.displayName ?? 'Unknown'}</Text>
          <Text style={sc.time}>{formatTime(share.timestamp)}</Text>
        </View>
        <TypeBadge type={share.type} />
      </View>
      <PayloadCard share={share} />
      {share.note ? <Text style={sc.note}>"{share.note}"</Text> : null}
      <View style={sc.reactionBar}>
        {REACTIONS.map(({ type, emoji }) => {
          const count  = share.reactions.filter(r => r.type === type).length;
          const active = share.reactions.some(r => r.userId === myUserId && r.type === type);
          return (
            <Pressable
              key={type}
              style={[sc.reactionBtn, active && sc.reactionActive]}
              onPress={() => onReaction(type)}
            >
              <Text style={sc.reactionEmoji}>{emoji}</Text>
              {count > 0 && <Text style={[sc.reactionCount, active && { color: C.circles }]}>{count}</Text>}
            </Pressable>
          );
        })}
        <Pressable style={sc.commentToggle} onPress={onExpand}>
          <Text style={sc.commentToggleText}>
            💬{share.comments.length > 0 ? ` ${share.comments.length}` : ''} {expanded ? 'Hide' : 'Comment'}
          </Text>
        </Pressable>
      </View>
      {expanded && (
        <View style={sc.commentsSection}>
          {share.comments.map((c, i) => (
            <View key={i} style={sc.commentRow}>
              <Text style={sc.commentAvatar}>{members[c.userId]?.avatar ?? '🌿'}</Text>
              <View style={{ flex: 1 }}>
                <View style={sc.commentMeta}>
                  <Text style={sc.commentName}>{c.displayName}</Text>
                  <Text style={sc.commentTime}>{formatTime(c.timestamp)}</Text>
                </View>
                <Text style={sc.commentText}>{c.text}</Text>
              </View>
            </View>
          ))}
          <View style={sc.commentInputRow}>
            <TextInput
              style={sc.commentInput}
              placeholder="Add a comment…"
              placeholderTextColor={C.light}
              value={commentText}
              onChangeText={setCommentText}
              onSubmitEditing={submitComment}
              returnKeyType="send"
            />
            <Pressable
              style={[sc.commentSend, !commentText.trim() && sc.commentSendDisabled]}
              onPress={submitComment}
              disabled={!commentText.trim()}
            >
              <Text style={sc.commentSendText}>Send</Text>
            </Pressable>
          </View>
        </View>
      )}
    </View>
  );
}

const sc = StyleSheet.create({
  root:       { backgroundColor: C.surface, borderRadius: 14, padding: 16, marginBottom: 12, borderWidth: 1, borderColor: C.border },
  sharerRow:  { flexDirection: 'row', alignItems: 'flex-start', gap: 10, marginBottom: 12 },
  avatar:     { fontSize: 24 },
  sharerName: { fontSize: 14, fontWeight: '700', color: C.text },
  time:       { fontSize: 11, color: C.light, marginTop: 2 },
  note:       { fontSize: 13, color: C.muted, fontStyle: 'italic', lineHeight: 19, marginBottom: 12 },
  reactionBar:    { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 4, flexWrap: 'wrap' },
  reactionBtn:    { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: C.bg, borderWidth: 1, borderColor: C.border, borderRadius: 20, paddingVertical: 5, paddingHorizontal: 10 },
  reactionActive: { borderColor: C.circles, backgroundColor: C.circlesLt },
  reactionEmoji:  { fontSize: 14 },
  reactionCount:  { fontSize: 12, color: C.muted, fontWeight: '600' },
  commentToggle:     { marginLeft: 'auto' as any, paddingVertical: 5, paddingHorizontal: 10 },
  commentToggleText: { fontSize: 12, color: C.muted },
  commentsSection: { marginTop: 14, borderTopWidth: 1, borderTopColor: C.border, paddingTop: 12, gap: 10 },
  commentRow:    { flexDirection: 'row', gap: 8 },
  commentAvatar: { fontSize: 16, marginTop: 2 },
  commentMeta:   { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 3 },
  commentName:   { fontSize: 12, fontWeight: '700', color: C.text },
  commentTime:   { fontSize: 11, color: C.light },
  commentText:   { fontSize: 13, color: C.text, lineHeight: 18 },
  commentInputRow:  { flexDirection: 'row', gap: 8, marginTop: 6 },
  commentInput:     { flex: 1, backgroundColor: C.bg, borderWidth: 1, borderColor: C.border, borderRadius: 20, paddingHorizontal: 14, paddingVertical: 8, fontSize: 13, color: C.text },
  commentSend:         { backgroundColor: C.circles, borderRadius: 20, paddingHorizontal: 14, justifyContent: 'center' },
  commentSendDisabled: { opacity: 0.4 },
  commentSendText:     { color: C.white, fontWeight: '700', fontSize: 13 },
});

// ── Main Screen ───────────────────────────────────────────────────────────────

export function CircleDetailScreen() {
  const nav    = useNavigation<Nav>();
  const route  = useRoute<Route>();
  const insets = useSafeAreaInsets();
  const { circleId } = route.params;

  const [circle,      setCircle]      = useState<Circle | null>(null);
  const [shares,      setShares]      = useState<Share[]>([]);
  const [members,     setMembers]     = useState<Record<string, Member>>({});
  const [myProfile,   setMyProfile]   = useState<Member | null>(null);
  const [expandedId,  setExpandedId]  = useState<string | null>(null);

  // Invite modal
  const [inviteVisible,   setInviteVisible]   = useState(false);
  const [inviteLink,      setInviteLink]       = useState('');

  // Pending requests modal
  const [requestsVisible,  setRequestsVisible]  = useState(false);
  const [pendingRequests,  setPendingRequests]   = useState<PendingRequest[]>([]);

  const load = useCallback(async () => {
    const [allCircles, allShares, allMembers, profile] = await Promise.all([
      getCircles(),
      getShares(circleId),
      getAllMembers(),
      getProfile(),
    ]);
    const found = allCircles.find(c => c.id === circleId) ?? null;
    setCircle(found);
    setShares(allShares);
    setMembers(allMembers);
    setMyProfile(profile);
    if (found) setPendingRequests(found.pendingRequests ?? []);
  }, [circleId]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const openInvite = () => {
    if (!circle) return;
    setInviteLink(getInviteLink(circle));
    setInviteVisible(true);
  };

  const handleCopyLink = async () => {
    try {
      await RNShare.share({ message: inviteLink });
    } catch {}
  };

  const handleApprove = async (userId: string) => {
    await approveRequest(circleId, userId);
    await load();
  };

  const handleDecline = async (userId: string) => {
    await declineRequest(circleId, userId);
    await load();
  };

  const handleReaction = useCallback(async (shareId: string, type: ReactionType) => {
    if (!myProfile) return;
    const updated = await toggleReaction(circleId, shareId, myProfile.userId, type);
    setShares(updated);
  }, [circleId, myProfile]);

  const handleComment = useCallback(async (shareId: string, text: string) => {
    if (!myProfile) return;
    const comment: Comment = {
      userId:      myProfile.userId,
      displayName: myProfile.displayName,
      text,
      timestamp:   Date.now(),
    };
    const updated = await addComment(circleId, shareId, comment);
    setShares(updated);
  }, [circleId, myProfile]);

  const isOwner          = !!myProfile && circle?.ownerId === myProfile.userId;
  const pendingCount     = pendingRequests.length;

  return (
    <SafeAreaView style={s.root} edges={['top']}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>

        {/* Header */}
        <View style={s.header}>
          <Pressable onPress={() => nav.goBack()} hitSlop={8} style={s.backBtn}>
            <Text style={s.backText}>‹</Text>
          </Pressable>
          <View style={{ flex: 1 }}>
            <Text style={s.headerTitle} numberOfLines={1}>
              {circle?.emoji ?? ''} {circle?.name ?? ''}
            </Text>
            <Text style={s.headerSub}>
              {circle ? `${circle.memberIds.length} members` : ''}
            </Text>
          </View>
          {isOwner && pendingCount > 0 && (
            <Pressable style={s.requestsBadge} onPress={() => setRequestsVisible(true)}>
              <Text style={s.requestsBadgeText}>{pendingCount}</Text>
            </Pressable>
          )}
          <Pressable style={s.inviteBtn} onPress={openInvite}>
            <Text style={s.inviteBtnText}>Invite</Text>
          </Pressable>
          <Pressable style={s.shareBtn} onPress={() => nav.navigate('ShareToCircle', { circleId })}>
            <Text style={s.shareBtnText}>Share</Text>
          </Pressable>
        </View>

        <FlatList
          data={shares}
          keyExtractor={item => item.id}
          contentContainerStyle={[s.list, { paddingBottom: insets.bottom + 24 }]}
          renderItem={({ item }) => (
            <ShareCard
              share={item}
              members={members}
              myUserId={myProfile?.userId ?? ''}
              expanded={expandedId === item.id}
              onExpand={() => setExpandedId(prev => prev === item.id ? null : item.id)}
              onReaction={type => handleReaction(item.id, type)}
              onComment={text  => handleComment(item.id, text)}
            />
          )}
          ListEmptyComponent={
            <View style={s.empty}>
              <Text style={s.emptyEmoji}>📭</Text>
              <Text style={s.emptyTitle}>No shares yet</Text>
              <Text style={s.emptySub}>Be the first to share a discovery with this Circle.</Text>
            </View>
          }
        />
      </KeyboardAvoidingView>

      {/* ── Invite Modal ── */}
      <Modal visible={inviteVisible} transparent animationType="slide">
        <View style={m.overlay}>
          <View style={m.sheet}>
            <View style={m.headerRow}>
              <Text style={m.title}>Invite to {circle?.name}</Text>
              <Pressable onPress={() => setInviteVisible(false)} hitSlop={8}>
                <Text style={m.close}>✕</Text>
              </Pressable>
            </View>
            <Text style={m.sub}>Anyone with this link can request to join. You approve requests.</Text>

            <View style={m.qrWrap}>
              {inviteLink ? (
                <QRCode
                  value={inviteLink}
                  size={200}
                  color={C.accent}
                  backgroundColor={C.surface}
                  ecl="M"
                />
              ) : null}
            </View>

            <Pressable style={[m.btn, m.copyBtn]} onPress={handleCopyLink}>
              <Text style={m.copyBtnText}>Copy link</Text>
            </Pressable>
          </View>
        </View>
      </Modal>

      {/* ── Pending Requests Modal ── */}
      <Modal visible={requestsVisible} transparent animationType="slide">
        <View style={m.overlay}>
          <View style={m.sheet}>
            <View style={m.headerRow}>
              <Text style={m.title}>Join Requests</Text>
              <Pressable onPress={() => setRequestsVisible(false)} hitSlop={8}>
                <Text style={m.close}>✕</Text>
              </Pressable>
            </View>
            <ScrollView style={{ maxHeight: 340 }}>
              {pendingRequests.length === 0 ? (
                <Text style={m.emptyText}>No pending requests.</Text>
              ) : (
                pendingRequests.map(req => (
                  <View key={req.userId} style={m.requestRow}>
                    <Text style={m.requestAvatar}>{req.avatar}</Text>
                    <View style={{ flex: 1 }}>
                      <Text style={m.requestName}>{req.displayName}</Text>
                      <Text style={m.requestTime}>{formatTime(req.requestedAt)}</Text>
                    </View>
                    <Pressable style={m.approveBtn} onPress={() => handleApprove(req.userId)}>
                      <Text style={m.approveBtnText}>Approve</Text>
                    </Pressable>
                    <Pressable style={m.declineBtn} onPress={() => handleDecline(req.userId)}>
                      <Text style={m.declineBtnText}>✕</Text>
                    </Pressable>
                  </View>
                ))
              )}
            </ScrollView>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  root:    { flex: 1, backgroundColor: C.bg },
  header:  { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: C.border },
  backBtn: { width: 32, alignItems: 'center' },
  backText:{ fontSize: 28, color: C.text, lineHeight: 32 },
  headerTitle: { fontSize: 16, fontWeight: '700', color: C.text },
  headerSub:   { fontSize: 11, color: C.muted, marginTop: 1 },
  requestsBadge:     { width: 22, height: 22, borderRadius: 11, backgroundColor: C.danger, alignItems: 'center', justifyContent: 'center' },
  requestsBadgeText: { fontSize: 11, color: C.white, fontWeight: '700' },
  inviteBtn:    { backgroundColor: C.circlesLt, borderWidth: 1, borderColor: C.circles + '60', borderRadius: 16, paddingVertical: 6, paddingHorizontal: 10 },
  inviteBtnText:{ color: C.circles, fontWeight: '700', fontSize: 12 },
  shareBtn:     { backgroundColor: C.circles, borderRadius: 16, paddingVertical: 6, paddingHorizontal: 10 },
  shareBtnText: { color: C.white, fontWeight: '700', fontSize: 12 },
  list:  { padding: 16 },
  empty: { alignItems: 'center', paddingTop: 80, gap: 12 },
  emptyEmoji: { fontSize: 40 },
  emptyTitle: { fontSize: 17, fontWeight: '700', color: C.text },
  emptySub:   { fontSize: 13, color: C.muted, textAlign: 'center', lineHeight: 19, paddingHorizontal: 32 },
});

const m = StyleSheet.create({
  overlay:   { flex: 1, backgroundColor: '#00000066', justifyContent: 'flex-end' },
  sheet:     { backgroundColor: C.bg, borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 24, paddingBottom: 40 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 },
  title:     { fontSize: 18, fontWeight: '700', color: C.text, fontFamily: 'Georgia' },
  close:     { fontSize: 18, color: C.muted },
  sub:       { fontSize: 13, color: C.muted, lineHeight: 18, marginBottom: 24 },

  qrWrap: { alignItems: 'center', backgroundColor: C.surface, borderRadius: 16, padding: 24, marginBottom: 20, borderWidth: 1, borderColor: C.border },

  btn:        { borderRadius: 12, paddingVertical: 13, alignItems: 'center', marginBottom: 10 },
  copyBtn:    { backgroundColor: C.circles },
  copyBtnText:{ color: C.white, fontWeight: '700', fontSize: 15 },
  shareBtn:   { backgroundColor: C.surface, borderWidth: 1, borderColor: C.border },
  shareBtnText:{ color: C.text, fontWeight: '600', fontSize: 15 },

  emptyText: { color: C.muted, fontSize: 14, textAlign: 'center', paddingVertical: 20 },
  requestRow:   { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: C.border },
  requestAvatar:{ fontSize: 22 },
  requestName:  { fontSize: 14, fontWeight: '600', color: C.text },
  requestTime:  { fontSize: 11, color: C.light },
  approveBtn:     { backgroundColor: C.circles, borderRadius: 8, paddingVertical: 6, paddingHorizontal: 12 },
  approveBtnText: { color: C.white, fontWeight: '700', fontSize: 12 },
  declineBtn:     { width: 30, height: 30, borderRadius: 15, backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, alignItems: 'center', justifyContent: 'center' },
  declineBtnText: { fontSize: 12, color: C.muted },
});
