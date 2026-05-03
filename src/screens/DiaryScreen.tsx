import React, { useState, useEffect, useCallback, useContext } from 'react';
import {
  View, Text, ScrollView, Pressable, StyleSheet,
  RefreshControl, Platform, StatusBar, Animated,
} from 'react-native';
import { dbAll, dbGetFirst, getDb, isDbReady } from '../db/database';
import { C } from '../theme/colors';

function ratingColor(v: number | null) {
  if (!v) return C.border;
  if (v <= 3) return C.danger;
  if (v <= 6) return C.amber;
  return C.sage;
}

function formatDate(isoString: string): string {
  const d = new Date(isoString);
  const now = new Date();
  const diffDays = Math.floor((now.getTime() - d.getTime()) / (1000*60*60*24));
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return d.toLocaleDateString('en-US', { weekday: 'long' });
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function groupByDate(sessions: any[]) {
  const groups: { date: string; label: string; sessions: any[] }[] = [];
  const seen: Record<string, any> = {};
  for (const s of sessions) {
    const key = s.session_at?.slice(0, 10) ?? 'unknown';
    if (!seen[key]) {
      seen[key] = { date: key, label: formatDate(s.session_at), sessions: [] };
      groups.push(seen[key]);
    }
    seen[key].sessions.push(s);
  }
  return groups;
}

function Sparkline({ session }: { session: any }) {
  const keys = [
    { key: 'effect_focus', label: 'F' },
    { key: 'effect_mood',  label: 'M' },
    { key: 'effect_sleep', label: 'S' },
    { key: 'effect_anxiety', label: 'C' },
    { key: 'effect_energy', label: 'E' },
  ];
  return (
    <View style={{ flexDirection: 'row', gap: 4, alignItems: 'flex-end' }}>
      {keys.map(({ key, label }) => {
        const val = session[key];
        const h   = val ? Math.round((val / 10) * 20) : 2;
        const col = val ? ratingColor(val) : C.border;
        return (
          <View key={key} style={{ alignItems: 'center', gap: 2 }}>
            <View style={{ width: 12, height: 20, justifyContent: 'flex-end' }}>
              <View style={{ width: 12, height: h, borderRadius: 2, backgroundColor: col }} />
            </View>
            <Text style={{ fontSize: 8, color: C.light }}>{label}</Text>
          </View>
        );
      })}
    </View>
  );
}


function EffectChips({ session }: { session: any }) {
  const chips: { label: string; color: string; bg: string }[] = [];

  // Couch-lock
  if (session.couch_lock_intent === 'wanted') {
    chips.push({ label: 'couch-lock', color: '#0F6E56', bg: '#E1F5EE' });
  } else if (session.couch_lock_intent === 'unwanted') {
    chips.push({ label: 'couch-lock', color: '#B85450', bg: '#F0DDDB' });
  } else if (session.couch_lock_intent === 'neutral') {
    chips.push({ label: 'couch-lock', color: '#8A7A6A', bg: '#F2EDE4' });
  }

  // Hunger
  if (session.hunger_intent === 'wanted') {
    chips.push({ label: 'munchies', color: '#0F6E56', bg: '#E1F5EE' });
  } else if (session.hunger_intent === 'unwanted') {
    chips.push({ label: 'munchies', color: '#B85450', bg: '#F0DDDB' });
  } else if (session.hunger_intent === 'neutral') {
    chips.push({ label: 'munchies', color: '#8A7A6A', bg: '#F2EDE4' });
  }

  // True side effects — always negative
  if (session.side_paranoia)  chips.push({ label: 'paranoia',  color: '#B85450', bg: '#F0DDDB' });
  if (session.side_headache)  chips.push({ label: 'headache',  color: '#B85450', bg: '#F0DDDB' });
  if (session.side_anxiety)   chips.push({ label: 'anxiety',   color: '#B85450', bg: '#F0DDDB' });
  if (session.side_dry_mouth) chips.push({ label: 'dry mouth', color: '#8A7A6A', bg: '#F2EDE4' });

  if (chips.length === 0) return null;

  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 5, paddingHorizontal: 13, paddingBottom: 10 }}>
      {chips.map((chip, i) => (
        <View key={i} style={{
          backgroundColor: chip.bg, borderRadius: 4,
          paddingHorizontal: 7, paddingVertical: 2,
        }}>
          <Text style={{ fontSize: 11, color: chip.color }}>{chip.label}</Text>
        </View>
      ))}
    </View>
  );
}

function SessionCard({ session, onPress }: { session: any; onPress: () => void }) {
  const color = ratingColor(session.overall_rating);
  const METHOD: Record<string,string> = {
    flower:'Flower', vape:'Vape', edible:'Edible',
    concentrate:'Conc.', tincture:'Tinct.', other:'Other',
  };
  return (
    <Pressable onPress={onPress}
      style={({ pressed }) => [s.card, pressed && { opacity: 0.85 }]}>
      <View style={[s.accentBar, { backgroundColor: color }]} />
      <View style={s.cardBody}>
        <View style={s.cardTop}>
          <View style={{ flex: 1, marginRight: 8 }}>
            <Text style={s.strainName} numberOfLines={1}>
              {session.strain_name ?? 'Unknown strain'}
            </Text>
            {session.strain_brand && (
              <Text style={s.brandName}>{session.strain_brand}</Text>
            )}
          </View>
          <View style={s.methodPill}>
            <Text style={s.methodText}>{METHOD[session.method] ?? session.method ?? '—'}</Text>
          </View>
        </View>
        <View style={s.cardMid}>
          <Sparkline session={session} />
          <View style={{ alignItems: 'flex-end', gap: 4 }}>
            <View style={{ flexDirection: 'row', gap: 3 }}>
              {[2,4,6,8,10].map(t => (
                <View key={t} style={{
                  width: 6, height: 6, borderRadius: 3,
                  backgroundColor: session.overall_rating && session.overall_rating >= t ? color : C.border,
                }} />
              ))}
            </View>
            {session.overall_rating && (
              <Text style={{ fontSize: 11, fontFamily: 'Georgia', color }}>{session.overall_rating}/10</Text>
            )}
          </View>
        </View>
        <View style={s.cardBottom}>
          <Text style={s.contextText}>
            {session.time_of_day ?? ''}
            {session.dispensary_name ? ` · ${session.dispensary_name}` : ''}
          </Text>
        </View>
        <EffectChips session={session} />
        {session.notes && (
          <Text style={s.notePreview} numberOfLines={2}>{session.notes}</Text>
        )}
      </View>
    </Pressable>
  );
}

function EmptyState({ onLog }: { onLog: () => void }) {
  return (
    <View style={s.empty}>
      <Text style={s.emptyTitle}>Your journal is empty</Text>
      <Text style={s.emptyBody}>
        Log your first session to start building your personal strain profile.
      </Text>
      <Pressable style={s.emptyBtn} onPress={onLog}>
        <Text style={s.emptyBtnText}>Log first session</Text>
      </Pressable>
    </View>
  );
}

export function DiaryScreen({ navigation }: { navigation: any }) {
  const [sessions,     setSessions]     = useState<any[]>([]);
  const [sessionCount, setSessionCount] = useState(0);
  const [refreshing,   setRefreshing]   = useState(false);
  const [loading,      setLoading]      = useState(true);
  const fabScale = React.useRef(new Animated.Value(1)).current;

  const loadSessions = useCallback(async () => {
    if (!isDbReady()) return;
    try {
      const rows = await dbAll('SELECT * FROM v_diary LIMIT 200');
      setSessions(rows);
      const count = await dbGetFirst<{ n: number }>('SELECT COUNT(*) AS n FROM sessions');
      setSessionCount(count?.n ?? 0);
    } catch (err) {
      console.error('[Diary] Load error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => { loadSessions(); }, [loadSessions]);

  useEffect(() => {
    const unsub = navigation.addListener('focus', loadSessions);
    return unsub;
  }, [navigation, loadSessions]);

  const handleFab = useCallback(() => {
    Animated.sequence([
      Animated.timing(fabScale, { toValue: 0.9, duration: 80, useNativeDriver: true }),
      Animated.timing(fabScale, { toValue: 1,   duration: 120, useNativeDriver: true }),
    ]).start();
    navigation.navigate('LogSession');
  }, [navigation, fabScale]);

  const groups = groupByDate(sessions);

  return (
    <View style={s.root}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <View style={s.header}>
        <View>
          <Text style={s.headerTitle}>Journal</Text>
          {sessionCount > 0 && (
            <Text style={s.headerSub}>{sessionCount} session{sessionCount !== 1 ? 's' : ''}</Text>
          )}
        </View>
      </View>

      {loading ? (
        <View style={s.loadingState}>
          <Text style={s.loadingText}>Loading journal…</Text>
        </View>
      ) : sessions.length === 0 ? (
        <EmptyState onLog={() => navigation.navigate('LogSession')} />
      ) : (
        <ScrollView style={s.scroll} contentContainerStyle={s.scrollContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={refreshing}
              onRefresh={() => { setRefreshing(true); loadSessions(); }}
              tintColor={C.accent} />
          }>
          {groups.map(group => (
            <View key={group.date}>
              <View style={s.dateHeader}>
                <Text style={s.dateLabel}>{group.label}</Text>
                <View style={s.dateLine} />
              </View>
              {group.sessions.map(session => (
                <SessionCard key={session.id} session={session} onPress={() => navigation.navigate("LogSession", { sessionId: session.id })} />
              ))}
            </View>
          ))}
          <View style={{ height: 88 }} />
        </ScrollView>
      )}

      <Animated.View style={[s.fab, { transform: [{ scale: fabScale }] }]}>
        <Pressable onPress={handleFab} style={s.fabInner}>
          <Text style={s.fabIcon}>+</Text>
          <Text style={s.fabLabel}>Log session</Text>
        </Pressable>
      </Animated.View>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  header: { paddingHorizontal: 24, paddingTop: Platform.OS === 'ios' ? 60 : 28,
    paddingBottom: 16, borderBottomWidth: 0.5, borderBottomColor: C.border,
    backgroundColor: C.bg },
  headerTitle: { fontFamily: 'Georgia', fontSize: 28, color: C.text, letterSpacing: 0.3 },
  headerSub: { fontSize: 13, color: C.muted, marginTop: 2 },
  scroll: { flex: 1 },
  scrollContent: { paddingBottom: 20 },
  loadingState: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  loadingText: { fontFamily: 'Georgia', fontSize: 15, color: C.muted },
  dateHeader: { flexDirection: 'row', alignItems: 'center',
    paddingHorizontal: 20, paddingTop: 20, paddingBottom: 10, gap: 10 },
  dateLabel: { fontFamily: 'Georgia', fontSize: 13, color: C.muted, letterSpacing: 0.3 },
  dateLine: { flex: 1, height: 0.5, backgroundColor: C.border },
  card: { flexDirection: 'row', marginHorizontal: 16, marginBottom: 8,
    backgroundColor: C.white, borderRadius: 10, borderWidth: 0.5,
    borderColor: C.border, overflow: 'hidden' },
  accentBar: { width: 3 },
  cardBody: { flex: 1, padding: 13, gap: 8 },
  cardTop: { flexDirection: 'row', alignItems: 'flex-start' },
  strainName: { fontFamily: 'Georgia', fontSize: 16, color: C.text, letterSpacing: 0.2 },
  brandName: { fontSize: 12, color: C.muted, marginTop: 1 },
  methodPill: { backgroundColor: C.surface, borderRadius: 4, paddingHorizontal: 8,
    paddingVertical: 3, borderWidth: 0.5, borderColor: C.border },
  methodText: { fontSize: 11, color: C.muted },
  cardMid: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between' },
  cardBottom: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  contextText: { fontSize: 11, color: C.light },
  sideFlag: { backgroundColor: C.dangerLt, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2 },
  sideFlagText: { fontSize: 10, color: C.danger },
  notePreview: { fontSize: 12, color: C.muted, lineHeight: 17, fontStyle: 'italic' },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 40, gap: 14 },
  emptyTitle: { fontFamily: 'Georgia', fontSize: 22, color: C.text, textAlign: 'center', letterSpacing: 0.3 },
  emptyBody: { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 21 },
  emptyBtn: { marginTop: 8, backgroundColor: C.accent, paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8 },
  emptyBtnText: { color: C.white, fontSize: 15, fontWeight: '500' },
  fab: { position: 'absolute', bottom: Platform.OS === 'ios' ? 32 : 24, alignSelf: 'center' },
  fabInner: { flexDirection: 'row', alignItems: 'center', gap: 8,
    backgroundColor: C.accent, paddingHorizontal: 22, paddingVertical: 13,
    borderRadius: 28, elevation: 4 },
  fabIcon: { fontSize: 20, color: C.white, lineHeight: 22 },
  fabLabel: { fontSize: 15, color: C.white, fontWeight: '500', letterSpacing: 0.2 },
});
