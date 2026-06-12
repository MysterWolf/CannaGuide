import React, { useState, useCallback } from 'react';
import {
  View, Text, ScrollView, Pressable, StyleSheet,
  TextInput, Modal, StatusBar, RefreshControl,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { C } from '../../theme/colors';
import {
  getCircles, getProfile, saveProfile, getOrCreateProfile, getShares,
  getAllMembers, Circle, Share, Member,
} from '../../services/circles';
import type { CirclesStackParamList } from './CirclesNavigator';

type Nav = NativeStackNavigationProp<CirclesStackParamList, 'CirclesList'>;

const AVATAR_OPTIONS = ['🌿', '🔥', '💨', '⭐', '🌙', '🎯'];

function formatTime(ts: number): string {
  const diff = Date.now() - ts;
  if (diff < 60000)    return 'just now';
  if (diff < 3600000)  return `${Math.floor(diff / 60000)}m ago`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
  return `${Math.floor(diff / 86400000)}d ago`;
}

interface CircleWithPreview {
  circle:    Circle;
  lastShare: Share | null;
}

export function CirclesScreen() {
  const nav    = useNavigation<Nav>();
  const insets = useSafeAreaInsets();

  const [profile,  setProfile]  = useState<Member | null>(null);
  const [circles,  setCircles]  = useState<CircleWithPreview[]>([]);
  const [members,  setMembers]  = useState<Record<string, Member>>({});
  const [refreshing, setRefreshing] = useState(false);

  // Profile setup modal
  const [setupVisible, setSetupVisible] = useState(false);
  const [setupName,    setSetupName]    = useState('');
  const [setupAvatar,  setSetupAvatar]  = useState('🌿');

  const load = useCallback(async () => {
    const [p, allCircles, allMembers] = await Promise.all([
      getProfile(),
      getCircles(),
      getAllMembers(),
    ]);
    setProfile(p);
    setMembers(allMembers);

    const withPreviews: CircleWithPreview[] = await Promise.all(
      allCircles.map(async c => {
        const shares = await getShares(c.id);
        return { circle: c, lastShare: shares[0] ?? null };
      }),
    );
    setCircles(withPreviews);
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  const handleSaveProfile = async () => {
    if (!setupName.trim()) return;
    const draft = await getOrCreateProfile();
    const m: Member = { ...draft, displayName: setupName.trim(), avatar: setupAvatar };
    await saveProfile(m);
    setProfile(m);
    setSetupVisible(false);
  };

  const noProfile = !profile?.displayName;

  return (
    <SafeAreaView style={s.root} edges={['top']}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />

      {/* Header */}
      <View style={s.header}>
        <Text style={s.title}>Circles</Text>
        <Pressable
          style={s.addBtn}
          onPress={() => noProfile ? setSetupVisible(true) : nav.navigate('CreateCircle')}
          hitSlop={8}
        >
          <Text style={s.addBtnText}>+</Text>
        </Pressable>
      </View>

      {/* Profile setup prompt */}
      {noProfile && (
        <Pressable style={s.setupBanner} onPress={() => setSetupVisible(true)}>
          <Text style={s.setupBannerEmoji}>👤</Text>
          <View style={{ flex: 1 }}>
            <Text style={s.setupBannerTitle}>Set your Circles name</Text>
            <Text style={s.setupBannerSub}>Choose a display name before creating or joining Circles.</Text>
          </View>
          <Text style={[s.setupBannerTitle, { color: C.circles }]}>Set up →</Text>
        </Pressable>
      )}

      <ScrollView
        contentContainerStyle={[s.scroll, { paddingBottom: insets.bottom + 16 }]}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={handleRefresh} tintColor={C.circles} />}
      >
        {circles.length === 0 ? (
          <View style={s.empty}>
            <Text style={s.emptyEmoji}>⭕</Text>
            <Text style={s.emptyTitle}>No Circles yet</Text>
            <Text style={s.emptySub}>Create a Circle and share discoveries with people you trust.</Text>
            <Pressable
              style={s.emptyBtn}
              onPress={() => noProfile ? setSetupVisible(true) : nav.navigate('CreateCircle')}
            >
              <Text style={s.emptyBtnText}>Create a Circle</Text>
            </Pressable>
          </View>
        ) : (
          circles.map(({ circle, lastShare }) => (
            <Pressable
              key={circle.id}
              style={s.card}
              onPress={() => nav.navigate('CircleDetail', { circleId: circle.id })}
            >
              <View style={s.cardTop}>
                <Text style={s.cardEmoji}>{circle.emoji}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={s.cardName}>{circle.name}</Text>
                  <Text style={s.cardMeta}>
                    {circle.memberIds.length} {circle.memberIds.length === 1 ? 'member' : 'members'}
                  </Text>
                </View>
                {profile && circle.ownerId === profile.userId && (circle.pendingRequests?.length ?? 0) > 0 && (
                  <View style={s.pendingBadge}>
                    <Text style={s.pendingBadgeText}>{circle.pendingRequests.length}</Text>
                  </View>
                )}
                <Text style={s.chevron}>›</Text>
              </View>
              {lastShare && (
                <View style={s.previewRow}>
                  <Text style={s.previewAvatar}>
                    {members[lastShare.sharerId]?.avatar ?? '🌿'}
                  </Text>
                  <Text style={s.previewText} numberOfLines={1}>
                    {members[lastShare.sharerId]?.displayName ?? 'Someone'} shared{' '}
                    {(lastShare.payload as any).name}
                  </Text>
                  <Text style={s.previewTime}>{formatTime(lastShare.timestamp)}</Text>
                </View>
              )}
            </Pressable>
          ))
        )}
      </ScrollView>

      {/* Profile setup modal */}
      <Modal visible={setupVisible} transparent animationType="slide">
        <View style={s.modalOverlay}>
          <View style={s.modalSheet}>
            <View style={s.modalHeader}>
              <Text style={s.modalTitle}>Your Circles Profile</Text>
              <Pressable onPress={() => setSetupVisible(false)} hitSlop={8}>
                <Text style={s.modalClose}>✕</Text>
              </Pressable>
            </View>

            <Text style={s.fieldLabel}>Display name</Text>
            <TextInput
              style={s.input}
              placeholder="How your Circle sees you"
              placeholderTextColor={C.light}
              value={setupName}
              onChangeText={setSetupName}
              autoFocus
              maxLength={32}
            />

            <Text style={s.fieldLabel}>Avatar</Text>
            <View style={s.avatarRow}>
              {AVATAR_OPTIONS.map(e => (
                <Pressable
                  key={e}
                  style={[s.avatarOption, setupAvatar === e && s.avatarSelected]}
                  onPress={() => setSetupAvatar(e)}
                >
                  <Text style={s.avatarEmoji}>{e}</Text>
                </Pressable>
              ))}
            </View>

            <Pressable
              style={[s.saveBtn, !setupName.trim() && s.saveBtnDisabled]}
              onPress={handleSaveProfile}
              disabled={!setupName.trim()}
            >
              <Text style={s.saveBtnText}>Save</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  root:   { flex: 1, backgroundColor: C.bg },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12 },
  title:  { fontSize: 26, fontFamily: 'Georgia', color: C.text, fontWeight: '700' },
  addBtn: { width: 36, height: 36, borderRadius: 18, backgroundColor: C.circles, alignItems: 'center', justifyContent: 'center' },
  addBtnText: { fontSize: 22, color: C.white, lineHeight: 28, marginTop: -2 },

  setupBanner: { flexDirection: 'row', alignItems: 'center', gap: 12, marginHorizontal: 16, marginBottom: 12, backgroundColor: C.circlesLt, borderRadius: 12, padding: 14, borderWidth: 1, borderColor: C.circles + '40' },
  setupBannerEmoji: { fontSize: 24 },
  setupBannerTitle: { fontSize: 13, fontWeight: '600', color: C.text },
  setupBannerSub:   { fontSize: 12, color: C.muted, marginTop: 2 },

  scroll: { paddingHorizontal: 16, paddingTop: 4 },

  card:    { backgroundColor: C.surface, borderRadius: 14, padding: 16, marginBottom: 12, borderWidth: 1, borderColor: C.border },
  cardTop: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 10 },
  cardEmoji: { fontSize: 28 },
  cardName:  { fontSize: 16, fontWeight: '700', color: C.text },
  cardMeta:  { fontSize: 12, color: C.muted, marginTop: 2 },
  chevron:   { fontSize: 20, color: C.light },

  previewRow:   { flexDirection: 'row', alignItems: 'center', gap: 8, paddingTop: 10, borderTopWidth: 1, borderTopColor: C.border },
  previewAvatar:{ fontSize: 14 },
  previewText:  { flex: 1, fontSize: 12, color: C.muted },
  previewTime:  { fontSize: 11, color: C.light },

  pendingBadge:     { width: 20, height: 20, borderRadius: 10, backgroundColor: C.danger, alignItems: 'center', justifyContent: 'center', marginRight: 4 },
  pendingBadgeText: { fontSize: 10, color: C.white, fontWeight: '700' },

  empty:     { alignItems: 'center', paddingTop: 80, gap: 12 },
  emptyEmoji:{ fontSize: 48 },
  emptyTitle:{ fontSize: 18, fontWeight: '700', color: C.text },
  emptySub:  { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 20, paddingHorizontal: 32 },
  emptyBtn:  { marginTop: 8, backgroundColor: C.circles, borderRadius: 24, paddingVertical: 12, paddingHorizontal: 28 },
  emptyBtnText: { color: C.white, fontWeight: '700', fontSize: 15 },

  modalOverlay: { flex: 1, backgroundColor: '#00000066', justifyContent: 'flex-end' },
  modalSheet:   { backgroundColor: C.bg, borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 24, paddingBottom: 40 },
  modalHeader:  { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 },
  modalTitle:   { fontSize: 18, fontWeight: '700', color: C.text, fontFamily: 'Georgia' },
  modalClose:   { fontSize: 18, color: C.muted },

  fieldLabel: { fontSize: 11, fontWeight: '600', color: C.muted, letterSpacing: 0.8, marginBottom: 8, textTransform: 'uppercase' },
  input:      { backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, borderRadius: 10, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15, color: C.text, marginBottom: 20 },

  avatarRow:     { flexDirection: 'row', gap: 10, marginBottom: 28 },
  avatarOption:  { width: 44, height: 44, borderRadius: 22, backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, alignItems: 'center', justifyContent: 'center' },
  avatarSelected:{ borderColor: C.circles, borderWidth: 2, backgroundColor: C.circlesLt },
  avatarEmoji:   { fontSize: 22 },

  saveBtn:         { backgroundColor: C.circles, borderRadius: 12, paddingVertical: 14, alignItems: 'center' },
  saveBtnDisabled: { opacity: 0.4 },
  saveBtnText:     { color: C.white, fontWeight: '700', fontSize: 15 },
});
