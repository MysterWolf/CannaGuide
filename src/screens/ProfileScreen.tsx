import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, Pressable, StyleSheet,
  Platform, StatusBar, ActivityIndicator,
} from 'react-native';
import { dbAll, dbGetFirst } from '../db/database';
import { C } from '../theme/colors';

// ============================================================
// HELPERS
// ============================================================
function daysSince(iso: string): number {
  return Math.floor((Date.now() - new Date(iso).getTime()) / (1000*60*60*24));
}
function safeJson(str: string | null, fallback: any = {}) {
  if (!str) return fallback;
  try { return JSON.parse(str); } catch { return fallback; }
}
function ratingColor(v: number | null) {
  if (!v) return C.border;
  if (v <= 3) return C.danger;
  if (v <= 6) return C.amber;
  return C.sage;
}
function roundTo(v: number, d = 1) {
  return Math.round(v * Math.pow(10, d)) / Math.pow(10, d);
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
function goalStyle(g: string) {
  return GOAL_COLORS[g] ?? { bg: C.surface, text: C.muted };
}

function toleranceColor(t: string | null) {
  if (t === 'low')    return C.sage;
  if (t === 'medium') return C.amber;
  if (t === 'high')   return C.danger;
  return C.light;
}

const EFFECT_META: Record<string, { label: string; color: string }> = {
  avg_focus:      { label: 'Focus',      color: C.sage },
  avg_sleep:      { label: 'Sleep',      color: C.blue },
  avg_anxiety:    { label: 'Calm',       color: C.sage },
  avg_mood:       { label: 'Mood',       color: C.amber },
  avg_creativity: { label: 'Creativity', color: C.purple },
  avg_energy:     { label: 'Energy',     color: C.amber },
};

// ============================================================
// SUB-COMPONENTS
// ============================================================

function SectionTitle({ children }: { children: string }) {
  return <Text style={s.sectionTitle}>{children}</Text>;
}

function Divider() {
  return <View style={s.divider} />;
}

function EffectBar({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <View style={s.effectBarRow}>
      <Text style={s.effectBarLabel}>{label}</Text>
      <View style={s.effectBarBg}>
        <View style={[s.effectBarFill, {
          width: `${roundTo((value / 10) * 100, 0)}%`,
          backgroundColor: color,
        }]} />
      </View>
      <Text style={[s.effectBarValue, { color }]}>{roundTo(value)}</Text>
    </View>
  );
}

function TerpeneRow({ name, value }: { name: string; value: number }) {
  const isPos  = value >= 0;
  const pct    = `${roundTo(Math.abs(value) * 100, 0)}%`;
  const color  = value >= 0.7 ? C.sage
    : value >= 0.3 ? C.amber
    : value >= 0    ? C.light
    : value >= -0.5 ? C.amber
    : C.danger;
  const label  = value >= 0.7 ? 'Strong fit'
    : value >= 0.3 ? 'Good fit'
    : value >= 0    ? 'Neutral'
    : value >= -0.5 ? 'Caution'
    : 'Avoid';

  return (
    <View style={s.terpRow}>
      <Text style={s.terpName}>{name}</Text>
      <View style={s.terpBarWrap}>
        <View style={s.terpNeg}>
          {!isPos && <View style={[s.terpBar, { width: pct, backgroundColor: color }]} />}
        </View>
        <View style={s.terpCentre} />
        <View style={s.terpPos}>
          {isPos && <View style={[s.terpBar, { width: pct, backgroundColor: color }]} />}
        </View>
      </View>
      <Text style={[s.terpLabel, { color }]}>{label}</Text>
    </View>
  );
}

function TopStrainCard({ strain, rank }: { strain: any; rank: number }) {
  const color = ratingColor(strain.avg_overall);
  return (
    <View style={s.strainCard}>
      <View style={[s.strainRank, { backgroundColor: rank === 1 ? C.accent : C.surface }]}>
        <Text style={[s.strainRankNum, { color: rank === 1 ? C.white : C.muted }]}>{rank}</Text>
      </View>
      <View style={s.strainBody}>
        <Text style={s.strainName}>{strain.name}</Text>
        {strain.brand && <Text style={s.strainBrand}>{strain.brand}</Text>}
        <Text style={s.strainSessions}>{strain.session_count} session{strain.session_count !== 1 ? 's' : ''}</Text>
      </View>
      <View style={s.strainRight}>
        <Text style={[s.strainRating, { color }]}>{roundTo(strain.avg_overall)}</Text>
        <Text style={s.strainRatingLabel}>/ 10</Text>
      </View>
    </View>
  );
}

function LockedState({ sessionCount, onUpgrade }: { sessionCount: number; onUpgrade: () => void }) {
  const needed = Math.max(0, 5 - sessionCount);
  return (
    <View style={s.lockedState}>
      <View style={s.lockedIcon}>
        <Text style={{ fontSize: 24, color: C.accent }}>◈</Text>
      </View>
      <Text style={s.lockedTitle}>Your effect profile</Text>
      <Text style={s.lockedBody}>
        {sessionCount < 5
          ? `Log ${needed} more session${needed !== 1 ? 's' : ''} to build your personal terpene and effect profile.`
          : 'Your profile is ready. Upgrade to Pro to unlock your full effect profile and AI usage insights.'}
      </Text>
      {sessionCount >= 5 && (
        <Pressable style={s.unlockBtn} onPress={onUpgrade}>
          <Text style={s.unlockBtnText}>Unlock Pro — $6.99/mo</Text>
        </Pressable>
      )}
      {sessionCount < 5 && (
        <View style={{ alignItems: 'center', gap: 6, width: '100%' }}>
          <View style={s.progBg}>
            <View style={[s.progFill, { width: `${Math.min(100, (sessionCount / 5) * 100)}%` }]} />
          </View>
          <Text style={{ fontSize: 12, color: C.light }}>{sessionCount} / 5 sessions</Text>
        </View>
      )}
    </View>
  );
}

// ============================================================
// MAIN SCREEN
// ============================================================
export function ProfileScreen({ navigation }: { navigation: any }) {
  const isPro = true; // same test flag as RecommendScreen

  const [profile,      setProfile]      = useState<any>(null);
  const [topStrains,   setTopStrains]   = useState<any[]>([]);
  const [usageSummary, setUsageSummary] = useState<any[]>([]);
  const [sessionCount, setSessionCount] = useState(0);
  const [loading,      setLoading]      = useState(true);

  const loadData = useCallback(async () => {
    try {
      const p = await dbGetFirst<any>(
        'SELECT * FROM user_effect_profile ORDER BY generated_at DESC LIMIT 1'
      );
      setProfile(p ?? null);

      const c = await dbGetFirst<{ n: number }>('SELECT COUNT(*) AS n FROM sessions');
      setSessionCount(c?.n ?? 0);

      if (isPro) {
        let strains: any[] = [];
        try { strains = await dbAll(
          `SELECT * FROM v_strain_ratings
           WHERE session_count >= 1 AND avg_overall IS NOT NULL
           ORDER BY avg_overall DESC, session_count DESC LIMIT 5`
        ); } catch(e) { console.log('[Profile] strains error:', e); }
        setTopStrains(strains);

        const usage: any[] = []; // populated after first real API calls
        setUsageSummary(usage);
      }
    } catch (err) {
      console.error('[Profile] Load error:', err);
    } finally {
      setLoading(false);
    }
  }, [isPro]);

  useEffect(() => { loadData(); }, [loadData]);
  useEffect(() => {
    const unsub = navigation.addListener('focus', loadData);
    return unsub;
  }, [navigation, loadData]);

  if (loading) {
    return (
      <View style={[s.root, { alignItems: 'center', justifyContent: 'center' }]}>
        <ActivityIndicator color={C.accent} />
      </View>
    );
  }

  return (
    <View style={s.root}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <View style={s.header}>
        <Text style={s.headerTitle}>Profile</Text>
        {isPro && profile && (
          <Text style={s.headerSub}>
            Updated {daysSince(profile.generated_at) === 0 ? 'today' : `${daysSince(profile.generated_at)}d ago`}
          </Text>
        )}
      </View>

      {(!isPro || !profile) ? (
        <ScrollView style={s.scroll} contentContainerStyle={s.scrollContent}>
          <LockedState
            sessionCount={sessionCount}
            onUpgrade={() => alert('Pro coming soon!')}
          />
          {/* Still show top strains even without AI profile */}
          {topStrains.length > 0 && (
            <>
              <Divider />
              <View style={s.section}>
                <SectionTitle>Your top strains</SectionTitle>
                <Text style={s.sectionSub}>Ranked by your average rating</Text>
                {topStrains.map((strain, i) => (
                  <TopStrainCard key={strain.id} strain={strain} rank={i + 1} />
                ))}
              </View>
            </>
          )}
        </ScrollView>
      ) : (
        <ScrollView style={s.scroll} contentContainerStyle={s.scrollContent}
          showsVerticalScrollIndicator={false}>

          {/* 1. PROFILE HEADER */}
          <View style={s.section}>
            <View style={s.goalRow}>
              {profile.primary_goal && (() => {
                const gs = goalStyle(profile.primary_goal);
                return (
                  <View style={[s.goalChip, { backgroundColor: gs.bg }]}>
                    <Text style={[s.goalChipText, { color: gs.text }]}>
                      Primary: {profile.primary_goal}
                    </Text>
                  </View>
                );
              })()}
              {profile.secondary_goal && (() => {
                const gs = goalStyle(profile.secondary_goal);
                return (
                  <View style={[s.goalChip, { backgroundColor: gs.bg }]}>
                    <Text style={[s.goalChipText, { color: gs.text }]}>
                      {profile.secondary_goal}
                    </Text>
                  </View>
                );
              })()}
            </View>
            {profile.claude_reasoning && (
              <Text style={s.reasoning}>{profile.claude_reasoning}</Text>
            )}
            <Text style={s.sessionsMeta}>Built from {profile.sessions_analyzed} sessions</Text>
          </View>

          <Divider />

          {/* 2. EFFECT BREAKDOWN */}
          {topStrains.length > 0 && (() => {
            const avgEffects: Record<string, number> = {};
            for (const key of Object.keys(EFFECT_META)) {
              const vals = topStrains.map(s => s[key]).filter(Boolean);
              if (vals.length) avgEffects[key] = vals.reduce((a, b) => a + b, 0) / vals.length;
            }
            const hasEffects = Object.keys(avgEffects).length > 0;
            if (!hasEffects) return null;
            return (
              <View style={s.section}>
                <SectionTitle>What you optimise for</SectionTitle>
                <Text style={s.sectionSub}>Average ratings across your best sessions</Text>
                {Object.entries(EFFECT_META).map(([key, meta]) =>
                  avgEffects[key] ? (
                    <EffectBar key={key} label={meta.label} value={avgEffects[key]} color={meta.color} />
                  ) : null
                )}
              </View>
            );
          })()}

          <Divider />

          {/* 3. TERPENE MAP */}
          {(() => {
            const terps = safeJson(profile.terpene_affinities, {});
            const entries = Object.entries(terps).sort(([,a],[,b]) => (b as number) - (a as number));
            if (!entries.length) return null;
            return (
              <View style={s.section}>
                <SectionTitle>Terpene affinities</SectionTitle>
                <Text style={s.sectionSub}>How you respond to key terpenes</Text>
                <View style={s.terpAxis}>
                  <Text style={s.terpAxisLabel}>Avoid</Text>
                  <Text style={s.terpAxisLabel}>Neutral</Text>
                  <Text style={s.terpAxisLabel}>Seek</Text>
                </View>
                {entries.map(([name, value]) => (
                  <TerpeneRow key={name} name={name} value={value as number} />
                ))}
              </View>
            );
          })()}

          <Divider />

          {/* 4. CONTEXT PREFERENCES */}
          <View style={s.section}>
            <SectionTitle>When it works best</SectionTitle>
            <View style={s.contextGrid}>
              {[
                { label: 'Method',      value: profile.best_method },
                { label: 'Time',        value: profile.best_time_of_day },
                { label: 'Setting',     value: profile.best_setting },
                { label: 'Tolerance',   value: profile.tolerance_level,
                  color: toleranceColor(profile.tolerance_level) },
              ].filter(i => i.value).map(item => (
                <View key={item.label} style={s.contextCard}>
                  <Text style={s.contextLabel}>{item.label}</Text>
                  <Text style={[s.contextValue, item.color ? { color: item.color } : {}]}>
                    {(item.value as string).charAt(0).toUpperCase() + (item.value as string).slice(1)}
                  </Text>
                </View>
              ))}
            </View>
          </View>

          <Divider />

          {/* 5. SENSITIVITY FLAGS */}
          <View style={s.section}>
            <SectionTitle>Sensitivity flags</SectionTitle>
            <Text style={s.sectionSub}>Derived from your side effect history</Text>
            <View style={s.flagsCol}>
              <View style={[s.flagPill,
                profile.paranoia_sensitive === 1
                  ? { backgroundColor: C.dangerLt, borderColor: C.danger }
                  : { backgroundColor: C.surface, borderColor: C.border }
              ]}>
                <View style={[s.flagDot, {
                  backgroundColor: profile.paranoia_sensitive === 1 ? C.danger : C.border
                }]} />
                <Text style={[s.flagText, {
                  color: profile.paranoia_sensitive === 1 ? C.danger : C.light
                }]}>
                  {profile.paranoia_sensitive === 1 ? 'Paranoia sensitive' : 'No paranoia issues'}
                </Text>
              </View>
            </View>
          </View>

          <Divider />

          {/* 6. TOP STRAINS */}
          {topStrains.length > 0 && (
            <View style={s.section}>
              <SectionTitle>Your top strains</SectionTitle>
              <Text style={s.sectionSub}>Ranked by your average rating</Text>
              {topStrains.map((strain, i) => (
                <TopStrainCard key={strain.id} strain={strain} rank={i + 1} />
              ))}
            </View>
          )}

          <Divider />

          {/* 7. AI USAGE */}
          {usageSummary.length > 0 && (
            <View style={s.section}>
              <SectionTitle>AI usage</SectionTitle>
              <Text style={s.sectionSub}>Claude API calls made on your behalf</Text>
              <View style={s.metricsGrid}>
                <View style={s.metricCard}>
                  <Text style={s.metricLabel}>Total cost</Text>
                  <Text style={s.metricValue}>
                    ${usageSummary.reduce((sum, r) => sum + (r.total_cost_usd ?? 0), 0).toFixed(4)}
                  </Text>
                  <Text style={s.metricSub}>all time</Text>
                </View>
                <View style={s.metricCard}>
                  <Text style={s.metricLabel}>Calls</Text>
                  <Text style={[s.metricValue, { color: C.accent }]}>
                    {usageSummary.reduce((sum, r) => sum + r.total_calls, 0)}
                  </Text>
                  <Text style={s.metricSub}>total</Text>
                </View>
              </View>
              <Text style={s.usageNote}>
                Your subscription covers all AI usage — shown here for transparency.
              </Text>
            </View>
          )}

          {/* 8. PROFILE HISTORY */}
          <View style={s.section}>
            <SectionTitle>Profile history</SectionTitle>
            <View style={s.histCard}>
              <View style={s.histRow}>
                <Text style={s.histLabel}>Last updated</Text>
                <Text style={s.histValue}>
                  {new Date(profile.generated_at).toLocaleDateString('en-US', {
                    month: 'long', day: 'numeric', year: 'numeric'
                  })}
                </Text>
              </View>
              <View style={s.histRow}>
                <Text style={s.histLabel}>Sessions analysed</Text>
                <Text style={s.histValue}>{profile.sessions_analyzed}</Text>
              </View>
              <View style={[s.histRow, { borderBottomWidth: 0 }]}>
                <Text style={s.histLabel}>Rebuild trigger</Text>
                <Text style={s.histValue}>Every 5 sessions</Text>
              </View>
            </View>
          </View>

          <View style={{ height: 40 }} />
        </ScrollView>
      )}
    </View>
  );
}

// ============================================================
// STYLES
// ============================================================
const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  header: {
    paddingHorizontal: 24,
    paddingTop: Platform.OS === 'ios' ? 60 : 28,
    paddingBottom: 16,
    flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between',
    borderBottomWidth: 0.5, borderBottomColor: C.border, backgroundColor: C.bg,
  },
  headerTitle: { fontFamily: 'Georgia', fontSize: 28, color: C.text, letterSpacing: 0.3 },
  headerSub:   { fontSize: 12, color: C.light, marginBottom: 3 },
  scroll:        { flex: 1 },
  scrollContent: { paddingVertical: 8 },
  section: { paddingHorizontal: 24, paddingVertical: 20, gap: 12 },
  sectionTitle: { fontFamily: 'Georgia', fontSize: 17, color: C.text, letterSpacing: 0.2 },
  sectionSub:   { fontSize: 13, color: C.muted, lineHeight: 18, marginTop: -6 },
  divider: { height: 0.5, backgroundColor: C.border, marginHorizontal: 24 },

  // Goal chips
  goalRow:  { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  goalChip: { paddingHorizontal: 12, paddingVertical: 5, borderRadius: 6 },
  goalChipText: { fontSize: 13, fontWeight: '500' },
  reasoning: {
    fontFamily: 'Georgia', fontSize: 15, color: C.text,
    lineHeight: 23, fontStyle: 'italic',
  },
  sessionsMeta: { fontSize: 12, color: C.light },

  // Effect bars
  effectBarRow:   { flexDirection: 'row', alignItems: 'center', gap: 10 },
  effectBarLabel: { fontSize: 13, color: C.muted, width: 72, flexShrink: 0 },
  effectBarBg:    { flex: 1, height: 6, backgroundColor: C.surface, borderRadius: 3, overflow: 'hidden' },
  effectBarFill:  { height: 6, borderRadius: 3 },
  effectBarValue: { fontSize: 12, width: 28, textAlign: 'right', flexShrink: 0 },

  // Terpene map
  terpAxis:      { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 2 },
  terpAxisLabel: { fontSize: 10, color: C.light, letterSpacing: 0.3 },
  terpRow:       { flexDirection: 'row', alignItems: 'center', gap: 8 },
  terpName:      { fontSize: 12, color: C.text, width: 80, flexShrink: 0 },
  terpBarWrap:   { flex: 1, flexDirection: 'row', alignItems: 'center', height: 14 },
  terpNeg:       { flex: 1, alignItems: 'flex-end', height: 8, justifyContent: 'center' },
  terpPos:       { flex: 1, alignItems: 'flex-start', height: 8, justifyContent: 'center' },
  terpBar:       { height: 8, borderRadius: 2 },
  terpCentre:    { width: 1, height: 14, backgroundColor: C.border, marginHorizontal: 2 },
  terpLabel:     { fontSize: 11, width: 56, textAlign: 'right', flexShrink: 0 },

  // Context
  contextGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  contextCard: {
    backgroundColor: C.surface, borderRadius: 8, borderWidth: 0.5,
    borderColor: C.border, padding: 12, minWidth: '45%', flex: 1, gap: 4,
  },
  contextLabel: { fontSize: 11, color: C.light, letterSpacing: 0.5, textTransform: 'uppercase' },
  contextValue: { fontFamily: 'Georgia', fontSize: 16, color: C.text, letterSpacing: 0.2 },

  // Sensitivity
  flagsCol:  { gap: 8 },
  flagPill:  { flexDirection: 'row', alignItems: 'center', gap: 8, padding: 12, borderRadius: 8, borderWidth: 0.5 },
  flagDot:   { width: 8, height: 8, borderRadius: 4 },
  flagText:  { fontSize: 13 },

  // Top strains
  strainCard:      { flexDirection: 'row', alignItems: 'center', backgroundColor: C.white, borderRadius: 8, borderWidth: 0.5, borderColor: C.border, overflow: 'hidden' },
  strainRank:      { width: 32, alignSelf: 'stretch', alignItems: 'center', justifyContent: 'center' },
  strainRankNum:   { fontFamily: 'Georgia', fontSize: 14 },
  strainBody:      { flex: 1, padding: 12, gap: 2 },
  strainName:      { fontFamily: 'Georgia', fontSize: 15, color: C.text, letterSpacing: 0.2 },
  strainBrand:     { fontSize: 12, color: C.muted },
  strainSessions:  { fontSize: 11, color: C.light },
  strainRight:     { paddingHorizontal: 14, alignItems: 'center' },
  strainRating:    { fontFamily: 'Georgia', fontSize: 20 },
  strainRatingLabel: { fontSize: 10, color: C.light },

  // Metrics
  metricsGrid: { flexDirection: 'row', gap: 8 },
  metricCard:  { flex: 1, backgroundColor: C.surface, borderRadius: 8, padding: 12, gap: 3 },
  metricLabel: { fontSize: 11, color: C.light, letterSpacing: 0.4, textTransform: 'uppercase' },
  metricValue: { fontFamily: 'Georgia', fontSize: 18, color: C.text },
  metricSub:   { fontSize: 11, color: C.light },
  usageNote:   { fontSize: 12, color: C.light, lineHeight: 17, fontStyle: 'italic' },

  // History
  histCard: { backgroundColor: C.white, borderRadius: 8, borderWidth: 0.5, borderColor: C.border, overflow: 'hidden' },
  histRow:  { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 12, borderBottomWidth: 0.5, borderBottomColor: C.border },
  histLabel: { fontSize: 13, color: C.muted },
  histValue: { fontFamily: 'Georgia', fontSize: 12, color: C.text },

  // Locked
  lockedState: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 36, gap: 14, paddingVertical: 60 },
  lockedIcon:  { width: 56, height: 56, borderRadius: 28, backgroundColor: C.accentLight, alignItems: 'center', justifyContent: 'center' },
  lockedTitle: { fontFamily: 'Georgia', fontSize: 22, color: C.text, textAlign: 'center', letterSpacing: 0.3 },
  lockedBody:  { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 21 },
  unlockBtn:   { marginTop: 8, backgroundColor: C.purple, paddingHorizontal: 24, paddingVertical: 13, borderRadius: 8 },
  unlockBtnText: { color: C.white, fontSize: 15, fontWeight: '500' },
  progBg:   { width: '70%', height: 4, backgroundColor: C.surface, borderRadius: 2, overflow: 'hidden' },
  progFill: { height: 4, backgroundColor: C.accent, borderRadius: 2 },
});
