import React, { useEffect, useState } from 'react';
import {
  View, Text, Pressable, StyleSheet, ActivityIndicator, StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp, RouteProp } from '@react-navigation/native-stack';
import { C } from '../../theme/colors';
import {
  getCircles, getProfile, getOrCreateProfile, getAllMembers,
  requestToJoin, Circle, Member,
} from '../../services/circles';
import { notifyJoinRequest } from '../../services/notifications';
import type { CirclesStackParamList } from './CirclesNavigator';

type Nav   = NativeStackNavigationProp<CirclesStackParamList, 'JoinCircle'>;
type Route = RouteProp<CirclesStackParamList, 'JoinCircle'>;

type Status = 'loading' | 'found' | 'not_found' | 'invalid_token' | 'already_member' | 'pending' | 'requested' | 'needs_profile';

export function JoinCircleScreen() {
  const nav   = useNavigation<Nav>();
  const route = useRoute<Route>();
  const { circleId, token } = route.params;

  const [status,  setStatus]  = useState<Status>('loading');
  const [circle,  setCircle]  = useState<Circle | null>(null);
  const [owner,   setOwner]   = useState<Member | null>(null);
  const [profile, setProfile] = useState<Member | null>(null);
  const [joining, setJoining] = useState(false);

  useEffect(() => {
    (async () => {
      const [circles, members, p] = await Promise.all([
        getCircles(),
        getAllMembers(),
        getProfile(),
      ]);

      if (!p?.displayName) {
        setStatus('needs_profile');
        return;
      }
      setProfile(p);

      const found = circles.find(c => c.id === circleId);
      if (!found) { setStatus('not_found'); return; }
      if (found.inviteToken !== token) { setStatus('invalid_token'); return; }

      setCircle(found);
      setOwner(members[found.ownerId] ?? null);

      if (found.memberIds.includes(p.userId)) {
        setStatus('already_member');
      } else if (found.pendingRequests.some(r => r.userId === p.userId)) {
        setStatus('pending');
      } else {
        setStatus('found');
      }
    })();
  }, [circleId, token]);

  const handleJoin = async () => {
    if (!profile || !circle || joining) return;
    setJoining(true);
    try {
      const result = await requestToJoin(circleId, token, profile);
      if (result === 'ok') {
        await notifyJoinRequest(circle.name, profile.displayName);
        setStatus('requested');
      } else if (result === 'already_member') {
        setStatus('already_member');
      } else {
        setStatus('pending');
      }
    } finally {
      setJoining(false);
    }
  };

  const renderBody = () => {
    if (status === 'loading') {
      return <ActivityIndicator size="large" color={C.circles} style={{ marginTop: 40 }} />;
    }

    if (status === 'needs_profile') {
      return (
        <View style={s.card}>
          <Text style={s.cardEmoji}>👤</Text>
          <Text style={s.cardTitle}>Set up your profile first</Text>
          <Text style={s.cardSub}>Open the Circles tab and set your display name before joining a Circle.</Text>
        </View>
      );
    }

    if (status === 'not_found' || status === 'invalid_token') {
      return (
        <View style={s.card}>
          <Text style={s.cardEmoji}>🔗</Text>
          <Text style={s.cardTitle}>Invalid invite link</Text>
          <Text style={s.cardSub}>This link may have expired or been changed. Ask the Circle owner for a fresh invite.</Text>
        </View>
      );
    }

    if (status === 'already_member') {
      return (
        <View style={s.card}>
          <Text style={s.cardEmoji}>{circle?.emoji ?? '⭕'}</Text>
          <Text style={s.cardTitle}>You're already in {circle?.name}</Text>
          <Pressable style={s.primaryBtn} onPress={() => nav.replace('CircleDetail', { circleId })}>
            <Text style={s.primaryBtnText}>Open Circle</Text>
          </Pressable>
        </View>
      );
    }

    if (status === 'pending' || status === 'requested') {
      return (
        <View style={s.card}>
          <Text style={s.cardEmoji}>{circle?.emoji ?? '⭕'}</Text>
          <Text style={s.cardTitle}>
            {status === 'requested' ? 'Request sent!' : 'Request pending'}
          </Text>
          <Text style={s.cardSub}>
            {status === 'requested'
              ? `${owner?.displayName ?? 'The owner'} will be notified and can approve your request.`
              : 'You already have a pending request to join this Circle.'}
          </Text>
        </View>
      );
    }

    // status === 'found'
    return (
      <View style={s.card}>
        <Text style={s.cardEmoji}>{circle?.emoji}</Text>
        <Text style={s.cardTitle}>{circle?.name}</Text>
        {owner && (
          <Text style={s.ownerLine}>
            {owner.avatar} Created by {owner.displayName}
          </Text>
        )}
        <Text style={s.memberCount}>
          {circle?.memberIds.length ?? 0} {circle?.memberIds.length === 1 ? 'member' : 'members'}
        </Text>

        <Pressable
          style={[s.primaryBtn, joining && s.primaryBtnDisabled]}
          onPress={handleJoin}
          disabled={joining}
        >
          {joining
            ? <ActivityIndicator size="small" color={C.white} />
            : <Text style={s.primaryBtnText}>Request to Join</Text>
          }
        </Pressable>
        <Text style={s.approvalNote}>
          Owner approval required. Your request will be sent for review.
        </Text>
      </View>
    );
  };

  return (
    <SafeAreaView style={s.root} edges={['top', 'bottom']}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />

      <View style={s.header}>
        <Pressable onPress={() => nav.navigate('CirclesList')} hitSlop={8}>
          <Text style={s.dismiss}>Close</Text>
        </Pressable>
      </View>

      <View style={s.body}>
        <Text style={s.headline}>Circle Invite</Text>
        {renderBody()}
      </View>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  root:    { flex: 1, backgroundColor: C.bg },
  header:  { paddingHorizontal: 20, paddingTop: 12, alignItems: 'flex-end' },
  dismiss: { fontSize: 15, color: C.muted },

  body:     { flex: 1, padding: 24, alignItems: 'center', justifyContent: 'center' },
  headline: { fontSize: 14, fontWeight: '600', color: C.circles, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 24 },

  card:      { width: '100%', backgroundColor: C.surface, borderRadius: 16, padding: 28, alignItems: 'center', gap: 12, borderWidth: 1, borderColor: C.border },
  cardEmoji: { fontSize: 52, marginBottom: 4 },
  cardTitle: { fontSize: 22, fontWeight: '700', color: C.text, fontFamily: 'Georgia', textAlign: 'center' },
  cardSub:   { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 20 },

  ownerLine:   { fontSize: 14, color: C.muted },
  memberCount: { fontSize: 13, color: C.light },

  primaryBtn:         { width: '100%', backgroundColor: C.circles, borderRadius: 12, paddingVertical: 14, alignItems: 'center', marginTop: 8 },
  primaryBtnDisabled: { opacity: 0.5 },
  primaryBtnText:     { color: C.white, fontWeight: '700', fontSize: 16 },
  approvalNote:       { fontSize: 12, color: C.light, textAlign: 'center' },
});
