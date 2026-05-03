import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, Pressable, StyleSheet,
  TextInput, ActivityIndicator, Platform, StatusBar, Alert,
} from 'react-native';
import { dbAll, dbGetFirst, dbRun, generateUUID, isoNow } from '../db/database';
import { C } from '../theme/colors';

// ============================================================
// TEMP: hardcode Pro = true for testing
// Replace with real tier check before release
// ============================================================
const IS_PRO_TEST = true;
const API_KEY     = 'YOUR_API_KEY_HERE'; // replace with your key

// ============================================================
// HELPERS
// ============================================================
function getCurrentTimeOfDay(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return 'morning';
  if (h >= 12 && h < 17) return 'afternoon';
  if (h >= 17 && h < 21) return 'evening';
  return 'night';
}

function confidenceColor(v: number) {
  if (v >= 0.75) return C.sage;
  if (v >= 0.5)  return C.amber;
  return C.light;
}

const GOAL_COLORS: Record<string, { bg: string; text: string }> = {
  sleep:          { bg: C.blueLt,   text: '#0C447C' },
  anxiety_relief: { bg: C.sageLt,   text: '#0F6E56' },
  creativity:     { bg: C.purpleLt, text: C.purpleMid },
  pain:           { bg: C.dangerLt, text: '#791F1F' },
  mood:           { bg: C.amberLt,  text: '#633806' },
  focus:          { bg: C.sageLt,   text: '#085041' },
  energy:         { bg: C.amberLt,  text: '#854F0B' },
};

function goalStyle(goal: string) {
  return GOAL_COLORS[goal] ?? { bg: C.surface, text: C.muted };
}

// ============================================================
// SUB-COMPONENTS
// ============================================================

function ProfileSummaryCard({ profile, onPress }: { profile: any; onPress: () => void }) {
  if (!profile) return null;
  const s = goalStyle(profile.primary_goal);
  return (
    <Pressable style={card.root} onPress={onPress}>
      <View style={card.top}>
        <View style={{ flex: 1 }}>
          <Text style={card.label}>Your effect profile</Text>
          <Text style={card.sub}>Based on {profile.sessions_analyzed} sessions</Text>
        </View>
        {profile.primary_goal && (
          <View style={[card.badge, { backgroundColor: s.bg }]}>
            <Text style={[card.badgeText, { color: s.text }]}>{profile.primary_goal}</Text>
          </View>
        )}
      </View>
      {profile.claude_reasoning && (
        <Text style={card.reasoning} numberOfLines={3}>{profile.claude_reasoning}</Text>
      )}
    </Pressable>
  );
}

const card = StyleSheet.create({
  root: {
    backgroundColor: C.white, borderRadius: 12,
    borderWidth: 0.5, borderColor: C.border, padding: 16, gap: 10,
  },
  top:  { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  label: { fontFamily: 'Georgia', fontSize: 15, color: C.text, letterSpacing: 0.2 },
  sub:   { fontSize: 12, color: C.muted, marginTop: 2 },
  badge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 6 },
  badgeText: { fontSize: 12, fontWeight: '500' },
  reasoning: { fontSize: 13, color: C.muted, lineHeight: 19, fontStyle: 'italic' },
});

function RecCard({ rec, rank }: { rec: any; rank: number }) {
  const [expanded, setExpanded] = useState(rank === 1);
  const color = confidenceColor(rec.confidence);

  return (
    <View style={rec_s.root}>
      <View style={[rec_s.rankCol, { backgroundColor: rank === 1 ? C.accent : C.surface }]}>
        <Text style={[rec_s.rankNum, { color: rank === 1 ? C.white : C.muted }]}>{rank}</Text>
      </View>
      <View style={rec_s.body}>
        <Pressable style={rec_s.head} onPress={() => setExpanded(e => !e)}>
          <View style={{ flex: 1 }}>
            <Text style={rec_s.name}>{rec.strain_name}</Text>
            {rec.brand && <Text style={rec_s.brand}>{rec.brand}</Text>}
          </View>
          <View style={rec_s.confWrap}>
            <Text style={[rec_s.confNum, { color }]}>{Math.round(rec.confidence * 100)}%</Text>
            <Text style={rec_s.confLabel}>match</Text>
          </View>
          <Text style={rec_s.chevron}>{expanded ? '↑' : '↓'}</Text>
        </Pressable>

        <View style={rec_s.confBarBg}>
          <View style={[rec_s.confBarFill, {
            width: `${Math.round(rec.confidence * 100)}%`,
            backgroundColor: color,
          }]} />
        </View>

        <Text style={rec_s.note}>{rec.user_note}</Text>

        {expanded && rec.match_reasons?.length > 0 && (
          <View style={rec_s.detail}>
            <Text style={rec_s.detailLabel}>Why it matches</Text>
            {rec.match_reasons.map((r: string, i: number) => (
              <View key={i} style={{ flexDirection: 'row', gap: 6 }}>
                <Text style={{ color: C.accent, fontSize: 14 }}>·</Text>
                <Text style={{ fontSize: 13, color: C.text, lineHeight: 18, flex: 1 }}>{r}</Text>
              </View>
            ))}
            {rec.cautions?.length > 0 && (
              <>
                <Text style={[rec_s.detailLabel, { color: C.amber, marginTop: 8 }]}>Heads up</Text>
                {rec.cautions.map((c: string, i: number) => (
                  <View key={i} style={{ flexDirection: 'row', gap: 6 }}>
                    <Text style={{ color: C.amber, fontSize: 12 }}>⚠</Text>
                    <Text style={{ fontSize: 13, color: C.muted, lineHeight: 18, flex: 1 }}>{c}</Text>
                  </View>
                ))}
              </>
            )}
          </View>
        )}
      </View>
    </View>
  );
}

const rec_s = StyleSheet.create({
  root: {
    flexDirection: 'row', backgroundColor: C.white,
    borderRadius: 12, borderWidth: 0.5, borderColor: C.border, overflow: 'hidden',
  },
  rankCol: { width: 32, alignItems: 'center', justifyContent: 'flex-start', paddingTop: 16 },
  rankNum: { fontFamily: 'Georgia', fontSize: 15 },
  body:    { flex: 1, padding: 14, gap: 8 },
  head:    { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  name:    { fontFamily: 'Georgia', fontSize: 16, color: C.text, letterSpacing: 0.2 },
  brand:   { fontSize: 12, color: C.muted, marginTop: 1 },
  confWrap:  { alignItems: 'center' },
  confNum:   { fontFamily: 'Georgia', fontSize: 16 },
  confLabel: { fontSize: 10, color: C.light, marginTop: -1 },
  chevron:   { fontSize: 16, color: C.light, marginTop: 2 },
  confBarBg:   { height: 3, backgroundColor: C.surface, borderRadius: 2, overflow: 'hidden' },
  confBarFill: { height: 3, borderRadius: 2 },
  note:   { fontSize: 13, color: C.muted, lineHeight: 19, fontStyle: 'italic' },
  detail: { borderTopWidth: 0.5, borderTopColor: C.border, paddingTop: 10, gap: 6 },
  detailLabel: {
    fontSize: 11, color: C.light, letterSpacing: 0.6,
    textTransform: 'uppercase', marginBottom: 2,
  },
});

function NoSessionsState({ count, navigation }: { count: number; navigation: any }) {
  const needed = Math.max(0, 5 - count);
  return (
    <View style={st.emptyState}>
      <Text style={st.emptyTitle}>
        {count === 0 ? 'Start your journal' : `${needed} more session${needed !== 1 ? 's' : ''} to go`}
      </Text>
      <Text style={st.emptyBody}>
        {count === 0
          ? 'Log your first session so CannaGuide can learn your preferences.'
          : `You have ${count} session${count !== 1 ? 's' : ''} logged. Keep going.`}
      </Text>
      <View style={st.progressBg}>
        <View style={[st.progressFill, { width: `${Math.min(100, (count / 5) * 100)}%` }]} />
      </View>
      <Text style={{ fontSize: 12, color: C.light }}>{count} / 5 sessions</Text>
      <Pressable style={st.logBtn}
        onPress={() => navigation.navigate('Diary', { screen: 'LogSession' })}>
        <Text style={st.logBtnText}>Log a session</Text>
      </Pressable>
    </View>
  );
}

function FreeTeaser({ sessionCount, onUpgrade }: { sessionCount: number; onUpgrade: () => void }) {
  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16 }}>
      <View style={st.teaserCard}>
        <Text style={st.teaserTitle}>Your profile is built</Text>
        <Text style={st.teaserBody}>
          CannaGuide has analysed your {sessionCount} sessions.
          Upgrade to Pro to unlock your profile and personalised picks.
        </Text>
        {[
          'Personal terpene & effect profile',
          '"Find me something" — context-aware picks',
          '"Can\'t find it?" — stock availability matcher',
          'Monthly insights report',
        ].map((f, i) => (
          <View key={i} style={{ flexDirection: 'row', gap: 10, alignItems: 'flex-start' }}>
            <Text style={{ fontSize: 12, color: C.accent, marginTop: 2 }}>✦</Text>
            <Text style={{ fontSize: 14, color: C.text, lineHeight: 20, flex: 1 }}>{f}</Text>
          </View>
        ))}
        <Pressable style={st.upgradeBtn} onPress={onUpgrade}>
          <Text style={st.upgradeBtnText}>Unlock Pro — $6.99/mo</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

// ============================================================
// MAIN SCREEN
// ============================================================
export function RecommendScreen({ navigation }: { navigation: any }) {
  const isPro = IS_PRO_TEST;

  const [profile,         setProfile]         = useState<any>(null);
  const [sessionCount,    setSessionCount]     = useState(0);
  const [recommendations, setRecommendations] = useState<any[] | null>(null);
  const [unavailNote,     setUnavailNote]      = useState<string | null>(null);
  const [loadingFind,     setLoadingFind]      = useState(false);
  const [loadingMatch,    setLoadingMatch]     = useState(false);
  const [loading,         setLoading]          = useState(true);
  const [targetStrain,    setTargetStrain]     = useState('');

  const loadData = useCallback(async () => {
    try {
      const p = await dbGetFirst<any>(
        'SELECT * FROM user_effect_profile ORDER BY generated_at DESC LIMIT 1'
      );
      setProfile(p ?? null);
      const c = await dbGetFirst<{ n: number }>('SELECT COUNT(*) AS n FROM sessions');
      setSessionCount(c?.n ?? 0);
    } catch (err) {
      console.error('[Recommend] Load error:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);
  useEffect(() => {
    const unsub = navigation.addListener('focus', loadData);
    return unsub;
  }, [navigation, loadData]);

  // ---- Find me something ----
  const handleFind = useCallback(async () => {
    setLoadingFind(true);
    setRecommendations(null);
    setUnavailNote(null);
    try {
      const sessions   = await dbAll('SELECT * FROM v_diary LIMIT 50');
      const strains    = await dbAll('SELECT * FROM v_strain_ratings WHERE session_count > 0 ORDER BY avg_overall DESC');
      const result     = await callClaudeRecommend({
        profile, sessions, strains,
        triggerType: 'manual',
        contextOverride: { time_of_day: getCurrentTimeOfDay() },
      });
      if (result?.recommendations) {
        setRecommendations(result.recommendations);
        setUnavailNote(null);
      }
    } catch (err: any) {
      Alert.alert('Something went wrong', err.message);
    } finally {
      setLoadingFind(false);
    }
  }, [profile]);

  // ---- Can't find it ----
  const handleUnavailable = useCallback(async () => {
    if (!targetStrain.trim()) {
      Alert.alert('Enter a strain name', 'Type the strain you cannot find.');
      return;
    }
    setLoadingMatch(true);
    setRecommendations(null);
    setUnavailNote(null);
    try {
      const sessions = await dbAll('SELECT * FROM v_diary LIMIT 50');
      const strains  = await dbAll('SELECT * FROM v_strain_ratings WHERE session_count > 0 ORDER BY avg_overall DESC');
      const result   = await callClaudeRecommend({
        profile, sessions, strains,
        triggerType:  'strain_unavailable',
        targetStrain: targetStrain.trim(),
        contextOverride: { time_of_day: getCurrentTimeOfDay() },
      });
      if (result?.recommendations) {
        setRecommendations(result.recommendations);
        setUnavailNote(result.if_unavailable_note ?? null);
      }
    } catch (err: any) {
      Alert.alert('Something went wrong', err.message);
    } finally {
      setLoadingMatch(false);
    }
  }, [profile, targetStrain]);

  if (loading) {
    return (
      <View style={[st.root, { alignItems: 'center', justifyContent: 'center' }]}>
        <ActivityIndicator color={C.accent} />
      </View>
    );
  }

  return (
    <View style={st.root}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <View style={st.header}>
        <Text style={st.headerTitle}>Recommend</Text>
        {isPro && (
          <View style={st.proBadge}>
            <Text style={st.proBadgeText}>Pro</Text>
          </View>
        )}
      </View>

      {sessionCount < 5 ? (
        <NoSessionsState count={sessionCount} navigation={navigation} />
      ) : !isPro ? (
        <FreeTeaser
          sessionCount={sessionCount}
          onUpgrade={() => Alert.alert('Pro', 'IAP coming soon!')}
        />
      ) : (
        <ScrollView style={st.scroll} contentContainerStyle={st.scrollContent}
          showsVerticalScrollIndicator={false}>

          {/* Profile summary */}
          <ProfileSummaryCard
            profile={profile}
            onPress={() => navigation.navigate('Profile')}
          />

          {/* Find me something */}
          <View style={st.findSection}>
            <Text style={st.findTitle}>Find me something</Text>
            <Text style={st.findSub}>
              Based on your profile — it's {getCurrentTimeOfDay()}.
            </Text>
            <Pressable
              style={[st.findBtn, loadingFind && { opacity: 0.6 }]}
              onPress={handleFind}
              disabled={loadingFind}>
              {loadingFind
                ? <ActivityIndicator color={C.white} size="small" />
                : <Text style={st.findBtnText}>Find a strain →</Text>
              }
            </Pressable>
          </View>

          {/* Can't find it */}
          <View style={st.unavailSection}>
            <Text style={st.unavailTitle}>Can't find it?</Text>
            <Text style={st.unavailSub}>
              Tell us what's out of stock — we'll find the closest match.
            </Text>
            <View style={st.unavailRow}>
              <TextInput
                style={st.unavailInput}
                placeholder="Strain name…"
                placeholderTextColor={C.light}
                value={targetStrain}
                onChangeText={setTargetStrain}
                autoCapitalize="words"
                returnKeyType="search"
                onSubmitEditing={handleUnavailable}
              />
              <Pressable
                style={[st.unavailBtn, (!targetStrain.trim() || loadingMatch) && { opacity: 0.3 }]}
                onPress={handleUnavailable}
                disabled={!targetStrain.trim() || loadingMatch}>
                {loadingMatch
                  ? <ActivityIndicator color={C.white} size="small" />
                  : <Text style={st.unavailBtnText}>Match</Text>
                }
              </Pressable>
            </View>
          </View>

          {/* Results */}
          {recommendations && recommendations.length > 0 && (
            <View style={{ gap: 10 }}>
              <Text style={st.resultsTitle}>
                {recommendations.length} recommendation{recommendations.length !== 1 ? 's' : ''}
              </Text>
              {unavailNote && (
                <View style={st.unavailNote}>
                  <Text style={st.unavailNoteText}>{unavailNote}</Text>
                </View>
              )}
              {recommendations.map((rec: any, i: number) => (
                <RecCard key={rec.strain_id ?? i} rec={rec} rank={i + 1} />
              ))}
            </View>
          )}

          {recommendations && recommendations.length === 0 && (
            <View style={st.unavailNote}>
              <Text style={st.unavailNoteText}>
                No strong matches found. Try logging more sessions to improve your profile.
              </Text>
            </View>
          )}

          <View style={{ height: 40 }} />
        </ScrollView>
      )}
    </View>
  );
}

// ============================================================
// CLAUDE API CALL (stubbed — returns mock data until key is set)
// ============================================================
async function callClaudeRecommend({
  profile, sessions, strains, triggerType, targetStrain, contextOverride,
}: {
  profile: any; sessions: any[]; strains: any[];
  triggerType: string; targetStrain?: string; contextOverride?: any;
}): Promise<any> {

  if (API_KEY === 'YOUR_API_KEY_HERE') {
    // Return mock data for UI testing
    await new Promise(r => setTimeout(r, 1500)); // simulate API delay
    return {
      recommendations: [
        {
          strain_id:     'mock-1',
          strain_name:   'Durban Poison',
          brand:         null,
          confidence:    0.91,
          match_reasons: [
            'Strong sativa — matches your afternoon focus pattern',
            'High limonene — your top positive terpene',
          ],
          terpene_alignment: { positive: ['limonene', 'terpinolene'], negative: [] },
          goal_match:    { primary: 0.92, secondary: 0.7 },
          cautions:      [],
          user_note:     'A classic focus strain with strong limonene — very close to what works for you in the afternoon.',
        },
        {
          strain_id:     'mock-2',
          strain_name:   'Jack Herer',
          brand:         null,
          confidence:    0.74,
          match_reasons: [
            'Terpinolene-forward — a terpene you respond well to',
            'Slightly lower THC than your usual — may feel milder',
          ],
          terpene_alignment: { positive: ['terpinolene', 'pinene'], negative: [] },
          goal_match:    { primary: 0.74, secondary: 0.6 },
          cautions:      ['Slightly below your typical THC range'],
          user_note:     'A well-rounded focus strain — the terpinolene profile should feel familiar.',
        },
      ],
      if_unavailable_note: targetStrain
        ? `${targetStrain} is known for its balanced terpene profile — these picks share similar characteristics.`
        : null,
      overall_reasoning: 'Based on your session history, you respond best to sativa-leaning strains in the afternoon.',
    };
  }

  // Real Claude API call
  const systemPrompt = `You are CannaGuide's strain recommendation engine. Based on the user's effect profile and session history, recommend the best cannabis strains. Return ONLY valid JSON matching this schema:
{
  "recommendations": [
    {
      "strain_id": string,
      "strain_name": string,
      "brand": string | null,
      "confidence": number,
      "match_reasons": [string],
      "terpene_alignment": { "positive": [string], "negative": [string] },
      "goal_match": { "primary": number, "secondary": number | null },
      "cautions": [string],
      "user_note": string
    }
  ],
  "if_unavailable_note": string | null,
  "overall_reasoning": string
}`;

  const userMessage = triggerType === 'strain_unavailable'
    ? `The user wants "${targetStrain}" but it's unavailable. Find the closest alternatives from their session history. Context: ${JSON.stringify(contextOverride)}. Profile: ${JSON.stringify(profile)}. Session history: ${JSON.stringify(sessions.slice(0, 20))}. Their top strains: ${JSON.stringify(strains.slice(0, 10))}.`
    : `Recommend strains for this user right now. Context: ${JSON.stringify(contextOverride)}. Profile: ${JSON.stringify(profile)}. Session history: ${JSON.stringify(sessions.slice(0, 20))}. Their top strains: ${JSON.stringify(strains.slice(0, 10))}.`;

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type':      'application/json',
      'x-api-key':         API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model:      'claude-sonnet-4-6',
      max_tokens: 1024,
      system:     systemPrompt,
      messages:   [{ role: 'user', content: userMessage }],
    }),
  });

  const data = await response.json();
  const text = data.content?.filter((b: any) => b.type === 'text').map((b: any) => b.text).join('') ?? '';
  const clean = text.replace(/```json\s*/i, '').replace(/```\s*$/i, '').trim();
  return JSON.parse(clean);
}

// ============================================================
// STYLES
// ============================================================
const st = StyleSheet.create({
  root:    { flex: 1, backgroundColor: C.bg },
  header:  {
    paddingHorizontal: 24,
    paddingTop: Platform.OS === 'ios' ? 60 : 28,
    paddingBottom: 16,
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    borderBottomWidth: 0.5, borderBottomColor: C.border, backgroundColor: C.bg,
  },
  headerTitle: { fontFamily: 'Georgia', fontSize: 28, color: C.text, letterSpacing: 0.3 },
  proBadge:    { backgroundColor: C.purpleLt, borderRadius: 4, paddingHorizontal: 8, paddingVertical: 3 },
  proBadgeText: { fontSize: 11, color: C.purpleMid, fontWeight: '500', letterSpacing: 0.5 },
  scroll:        { flex: 1 },
  scrollContent: { padding: 16, gap: 14 },

  // Find section
  findSection: {
    backgroundColor: C.accentLight, borderRadius: 12,
    borderWidth: 0.5, borderColor: '#D4B898', padding: 18, gap: 8,
  },
  findTitle: { fontFamily: 'Georgia', fontSize: 17, color: C.text, letterSpacing: 0.2 },
  findSub:   { fontSize: 13, color: C.muted, lineHeight: 18 },
  findBtn:   {
    backgroundColor: C.accent, borderRadius: 8,
    paddingVertical: 12, alignItems: 'center', marginTop: 4,
  },
  findBtnText: { color: C.white, fontSize: 15, fontWeight: '500' },

  // Unavailable section
  unavailSection: {
    backgroundColor: C.white, borderRadius: 12,
    borderWidth: 0.5, borderColor: C.border, padding: 16, gap: 10,
  },
  unavailTitle: { fontFamily: 'Georgia', fontSize: 15, color: C.text, letterSpacing: 0.2 },
  unavailSub:   { fontSize: 13, color: C.muted, lineHeight: 18 },
  unavailRow:   { flexDirection: 'row', gap: 8 },
  unavailInput: {
    flex: 1, backgroundColor: C.surface, borderRadius: 8,
    borderWidth: 0.5, borderColor: C.border,
    paddingHorizontal: 12, paddingVertical: 10, fontSize: 14, color: C.text,
  },
  unavailBtn: {
    backgroundColor: C.text, borderRadius: 8,
    paddingHorizontal: 16, justifyContent: 'center', alignItems: 'center',
  },
  unavailBtnText: { color: C.white, fontSize: 13, fontWeight: '500' },
  unavailNote: {
    backgroundColor: C.amberLt, borderRadius: 8, padding: 12,
    borderWidth: 0.5, borderColor: '#D4A860',
  },
  unavailNoteText: { fontSize: 13, color: '#633806', lineHeight: 19, fontStyle: 'italic' },

  // Results
  resultsTitle: {
    fontFamily: 'Georgia', fontSize: 15, color: C.muted, letterSpacing: 0.2,
  },

  // Empty / no sessions
  emptyState: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
    paddingHorizontal: 36, gap: 12,
  },
  emptyTitle: {
    fontFamily: 'Georgia', fontSize: 22, color: C.text,
    textAlign: 'center', letterSpacing: 0.3,
  },
  emptyBody: { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 21 },
  progressBg: {
    width: '80%', height: 4, backgroundColor: C.surface,
    borderRadius: 2, overflow: 'hidden',
  },
  progressFill: { height: 4, backgroundColor: C.accent, borderRadius: 2 },
  logBtn: {
    marginTop: 8, backgroundColor: C.accent,
    paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8,
  },
  logBtnText: { color: C.white, fontSize: 15, fontWeight: '500' },

  // Teaser
  teaserCard: {
    backgroundColor: C.white, borderRadius: 14,
    borderWidth: 0.5, borderColor: C.border,
    padding: 22, gap: 14, margin: 4,
  },
  teaserTitle: { fontFamily: 'Georgia', fontSize: 22, color: C.text, letterSpacing: 0.3 },
  teaserBody:  { fontSize: 14, color: C.muted, lineHeight: 21 },
  upgradeBtn:  {
    backgroundColor: C.purple, borderRadius: 10,
    paddingVertical: 14, alignItems: 'center', marginTop: 4,
  },
  upgradeBtnText: { color: C.white, fontSize: 15, fontWeight: '500', letterSpacing: 0.2 },
});
