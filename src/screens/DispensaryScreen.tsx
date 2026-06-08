import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, TextInput, Pressable,
  StyleSheet, Platform, Alert, ActivityIndicator,
} from 'react-native';
import { dbAll, dbRun, generateUUID, isoNow } from '../db/database';
import { C } from '../theme/colors';
import { useStashPass } from '../context/StashPassContext';
import * as SP from '../services/stashpass';

const VENUE_TYPES = [
  { id: 'dispensary', label: 'Dispensary' },
  { id: 'smoke_shop', label: 'Smoke shop' },
  { id: 'delivery',   label: 'Delivery' },
];

const PRICE_TIERS = [
  { id: 'budget',  label: 'Budget' },
  { id: 'mid',     label: 'Mid' },
  { id: 'premium', label: 'Premium' },
];

function ChipRow({ options, selected, onSelect }: {
  options: {id:string, label:string}[], selected: string|null, onSelect: (id:string)=>void
}) {
  return (
    <View style={s.chipRow}>
      {options.map(opt => (
        <Pressable key={opt.id} onPress={() => onSelect(opt.id)}
          style={[s.chip, selected === opt.id && s.chipActive]}>
          <Text style={[s.chipText, selected === opt.id && s.chipTextActive]}>
            {opt.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

function StarRow({ value, onChange, color = C.amber }: {
  value: number|null, onChange: (v:number|null)=>void, color?: string
}) {
  return (
    <View style={{ flexDirection: 'row', gap: 8 }}>
      {[1,2,3,4,5].map(n => (
        <Pressable key={n} onPress={() => onChange(value === n ? null : n)}>
          <Text style={{ fontSize: 28, color: value && n <= value ? color : C.border }}>
            ★
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

// ─── Wallet widget ────────────────────────────────────────────────────────────

function WalletWidget({ operatorId }: { operatorId: string }) {
  const { isConnected } = useStashPass();
  const [balance,     setBalance]     = useState<number | null>(null);
  const [dollarValue, setDollarValue] = useState(0);
  const [loadingBal,  setLoadingBal]  = useState(true);
  const [checkingIn,  setCheckingIn]  = useState(false);
  const [redeemMode,  setRedeemMode]  = useState(false);
  const [redeemInput, setRedeemInput] = useState('');
  const [redeeming,   setRedeeming]   = useState(false);

  const fetchBalance = useCallback(async () => {
    if (!isConnected) { setLoadingBal(false); return; }
    try {
      const r = await SP.getBalance(operatorId);
      setBalance(r.balance_points);
      setDollarValue(r.dollar_value);
    } catch {
      setBalance(null);
    } finally {
      setLoadingBal(false);
    }
  }, [isConnected, operatorId]);

  useEffect(() => { fetchBalance(); }, [fetchBalance]);

  if (!isConnected) {
    return (
      <View style={w.notLinked}>
        <Text style={w.notLinkedText}>Connect StashPass in Settings to earn points here</Text>
      </View>
    );
  }

  const handleCheckIn = async () => {
    setCheckingIn(true);
    try {
      const result = await SP.earn({ operatorId });
      const pts = result.transaction.points_delta;
      setBalance(result.transaction.balance_after);
      Alert.alert('Checked in!', `+${pts} point${pts !== 1 ? 's' : ''} earned.`);
    } catch (err: any) {
      Alert.alert('Check-in failed', err.message);
    } finally {
      setCheckingIn(false);
    }
  };

  const handleRedeem = async () => {
    const pts = parseInt(redeemInput, 10);
    if (!pts || pts <= 0) {
      Alert.alert('Invalid amount', 'Enter a positive number of points to redeem.');
      return;
    }
    if (balance !== null && pts > balance) {
      Alert.alert('Not enough points', `You only have ${balance} points.`);
      return;
    }
    setRedeeming(true);
    try {
      const result = await SP.redeem({ operatorId, points: pts });
      setBalance(result.transaction.balance_after);
      setRedeemMode(false);
      setRedeemInput('');
      const val = result.dollar_value.toFixed(2);
      Alert.alert('Redeemed!', `${pts} points redeemed — worth $${val}.`);
    } catch (err: any) {
      Alert.alert('Redeem failed', err.message);
    } finally {
      setRedeeming(false);
    }
  };

  return (
    <View style={w.container}>
      {/* Balance row */}
      <View style={w.balanceRow}>
        <View>
          {loadingBal ? (
            <ActivityIndicator size="small" color={C.accent} />
          ) : (
            <>
              <Text style={w.pts}>
                {balance !== null ? balance.toLocaleString() : '—'} pts
              </Text>
              {balance !== null && dollarValue > 0 && (
                <Text style={w.dollarVal}>${dollarValue.toFixed(2)} value</Text>
              )}
            </>
          )}
        </View>
        <View style={w.actions}>
          <Pressable
            onPress={handleCheckIn}
            disabled={checkingIn}
            style={[w.actionBtn, w.checkinBtn, checkingIn && { opacity: 0.5 }]}>
            {checkingIn
              ? <ActivityIndicator size="small" color={C.white} />
              : <Text style={w.actionBtnText}>Check in</Text>}
          </Pressable>
          <Pressable
            onPress={() => { setRedeemMode(m => !m); setRedeemInput(''); }}
            style={[w.actionBtn, w.redeemBtn]}>
            <Text style={[w.actionBtnText, { color: C.accent }]}>Redeem</Text>
          </Pressable>
        </View>
      </View>

      {/* Inline redeem form */}
      {redeemMode && (
        <View style={w.redeemRow}>
          <TextInput
            style={w.redeemInput}
            placeholder="Points to redeem"
            placeholderTextColor={C.light}
            value={redeemInput}
            onChangeText={setRedeemInput}
            keyboardType="numeric"
          />
          <Pressable
            onPress={handleRedeem}
            disabled={redeeming}
            style={[w.actionBtn, w.checkinBtn, { flex: 0 }, redeeming && { opacity: 0.5 }]}>
            {redeeming
              ? <ActivityIndicator size="small" color={C.white} />
              : <Text style={w.actionBtnText}>Confirm</Text>}
          </Pressable>
        </View>
      )}
    </View>
  );
}

// ─── Dispensary card ──────────────────────────────────────────────────────────

function DispensaryCard({ dispensary, onDelete }: { dispensary: any, onDelete: ()=>void }) {
  const vibeColor = !dispensary.vibe_rating ? C.light
    : dispensary.vibe_rating >= 4 ? C.sage
    : dispensary.vibe_rating >= 3 ? C.amber
    : C.danger;

  return (
    <View style={s.card}>
      <View style={s.cardTop}>
        <View style={{ flex: 1 }}>
          <Text style={s.cardName}>{dispensary.name}</Text>
          {dispensary.city && (
            <Text style={s.cardCity}>{dispensary.city}</Text>
          )}
          <View style={s.cardBadges}>
            {dispensary.venue_type && (
              <View style={s.badge}>
                <Text style={s.badgeText}>
                  {dispensary.venue_type.replace('_', ' ')}
                </Text>
              </View>
            )}
            {dispensary.price_tier && (
              <View style={[s.badge, { backgroundColor: C.amberLt }]}>
                <Text style={[s.badgeText, { color: C.amber }]}>
                  {dispensary.price_tier}
                </Text>
              </View>
            )}
            {dispensary.would_go_back === 0 && (
              <View style={[s.badge, { backgroundColor: C.dangerLt }]}>
                <Text style={[s.badgeText, { color: C.danger }]}>
                  Would not return
                </Text>
              </View>
            )}
            {dispensary.stashpass_operator_id && (
              <View style={[s.badge, { backgroundColor: C.sageLt }]}>
                <Text style={[s.badgeText, { color: C.sage }]}>StashPass</Text>
              </View>
            )}
          </View>
        </View>
        <Pressable onPress={onDelete} style={s.deleteBtn}>
          <Text style={s.deleteBtnText}>Remove</Text>
        </Pressable>
      </View>

      {(dispensary.vibe_rating || dispensary.staff_rating) && (
        <View style={s.cardRatings}>
          {dispensary.vibe_rating != null && (
            <View style={s.ratingRow}>
              <Text style={s.ratingLabel}>Vibe</Text>
              <View style={{ flexDirection: 'row', gap: 3 }}>
                {[1,2,3,4,5].map(n => (
                  <Text key={n} style={{
                    fontSize: 14,
                    color: dispensary.vibe_rating >= n ? vibeColor : C.border
                  }}>★</Text>
                ))}
              </View>
            </View>
          )}
          {dispensary.staff_rating != null && (
            <View style={s.ratingRow}>
              <Text style={s.ratingLabel}>Staff</Text>
              <View style={{ flexDirection: 'row', gap: 3 }}>
                {[1,2,3,4,5].map(n => (
                  <Text key={n} style={{
                    fontSize: 14,
                    color: dispensary.staff_rating >= n ? C.sage : C.border
                  }}>★</Text>
                ))}
              </View>
            </View>
          )}
        </View>
      )}

      {/* StashPass wallet — only rendered when operator is linked */}
      {dispensary.stashpass_operator_id && (
        <WalletWidget operatorId={dispensary.stashpass_operator_id} />
      )}
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export function DispensaryScreen({ navigation }: { navigation: any }) {
  const [dispensaries, setDispensaries] = useState<any[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [showForm,     setShowForm]     = useState(false);

  // Form state
  const [name,                setName]                = useState('');
  const [city,                setCity]                = useState('');
  const [venueType,           setVenueType]           = useState<string|null>(null);
  const [priceTier,           setPriceTier]           = useState<string|null>(null);
  const [vibeRating,          setVibeRating]          = useState<number|null>(null);
  const [staffRating,         setStaffRating]         = useState<number|null>(null);
  const [wouldReturn,         setWouldReturn]         = useState(true);
  const [stashpassOperatorId, setStashpassOperatorId] = useState('');
  const [saving,              setSaving]              = useState(false);

  const loadDispensaries = useCallback(async () => {
    try {
      const rows = await dbAll('SELECT * FROM dispensaries ORDER BY name ASC');
      setDispensaries(rows);
    } catch (err) {
      console.error('[Dispensary] Load error:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadDispensaries(); }, [loadDispensaries]);

  const resetForm = () => {
    setName(''); setCity(''); setVenueType(null); setPriceTier(null);
    setVibeRating(null); setStaffRating(null); setWouldReturn(true);
    setStashpassOperatorId('');
  };

  const handleSave = useCallback(async () => {
    if (!name.trim()) {
      Alert.alert('Name required', 'Please enter a dispensary name.');
      return;
    }
    setSaving(true);
    try {
      await dbRun(
        `INSERT INTO dispensaries
          (id, name, city, venue_type, price_tier,
           vibe_rating, staff_rating, would_go_back, created_at, stashpass_operator_id)
         VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [
          generateUUID(), name.trim(), city.trim()||null,
          venueType, priceTier, vibeRating, staffRating,
          wouldReturn ? 1 : 0, isoNow(),
          stashpassOperatorId.trim() || null,
        ]
      );
      resetForm();
      setShowForm(false);
      loadDispensaries();
    } catch (err: any) {
      Alert.alert('Save failed', err.message);
    } finally {
      setSaving(false);
    }
  }, [name, city, venueType, priceTier, vibeRating, staffRating, wouldReturn, stashpassOperatorId, loadDispensaries]);

  const handleDelete = useCallback((id: string, name: string) => {
    Alert.alert(
      'Remove dispensary',
      `Remove "${name}" from your list?`,
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Remove', style: 'destructive', onPress: async () => {
          await dbRun('DELETE FROM dispensaries WHERE id = ?', [id]);
          loadDispensaries();
        }},
      ]
    );
  }, [loadDispensaries]);

  return (
    <View style={s.root}>
      <View style={s.header}>
        <Pressable onPress={() => navigation.goBack()} style={s.backBtn}>
          <Text style={s.backText}>← Back</Text>
        </Pressable>
        <Text style={s.headerTitle}>Dispensaries</Text>
        <Pressable onPress={() => setShowForm(f => !f)} style={s.addBtn}>
          <Text style={s.addBtnText}>{showForm ? 'Cancel' : '+ Add'}</Text>
        </Pressable>
      </View>

      <ScrollView style={s.scroll} contentContainerStyle={s.scrollContent}
        showsVerticalScrollIndicator={false}>

        {/* Add form */}
        {showForm && (
          <View style={s.form}>
            <Text style={s.formTitle}>Add dispensary</Text>

            <TextInput style={s.input} placeholder="Name *"
              placeholderTextColor={C.light} value={name}
              onChangeText={setName} autoCapitalize="words" />
            <TextInput style={s.input} placeholder="City (optional)"
              placeholderTextColor={C.light} value={city}
              onChangeText={setCity} autoCapitalize="words" />

            <Text style={s.fieldLabel}>Type</Text>
            <ChipRow options={VENUE_TYPES} selected={venueType} onSelect={setVenueType} />

            <Text style={s.fieldLabel}>Price tier</Text>
            <ChipRow options={PRICE_TIERS} selected={priceTier} onSelect={setPriceTier} />

            <Text style={s.fieldLabel}>Vibe rating</Text>
            <StarRow value={vibeRating} onChange={setVibeRating} color={C.amber} />

            <Text style={s.fieldLabel}>Staff knowledge</Text>
            <StarRow value={staffRating} onChange={setStaffRating} color={C.sage} />

            <Text style={s.fieldLabel}>Would you go back?</Text>
            <View style={s.chipRow}>
              <Pressable
                onPress={() => setWouldReturn(true)}
                style={[s.chip, wouldReturn && s.chipActive]}>
                <Text style={[s.chipText, wouldReturn && s.chipTextActive]}>Yes</Text>
              </Pressable>
              <Pressable
                onPress={() => setWouldReturn(false)}
                style={[s.chip, !wouldReturn && s.chipDanger]}>
                <Text style={[s.chipText, !wouldReturn && s.chipTextDanger]}>No</Text>
              </Pressable>
            </View>

            <Text style={s.fieldLabel}>StashPass operator ID (optional)</Text>
            <TextInput
              style={s.input}
              placeholder="Paste operator UUID"
              placeholderTextColor={C.light}
              value={stashpassOperatorId}
              onChangeText={setStashpassOperatorId}
              autoCapitalize="none"
              autoCorrect={false}
            />

            <Pressable onPress={handleSave} disabled={saving}
              style={[s.saveBtn, saving && { opacity: 0.5 }]}>
              {saving
                ? <ActivityIndicator color={C.white} size="small" />
                : <Text style={s.saveBtnText}>Save dispensary</Text>
              }
            </Pressable>
          </View>
        )}

        {/* List */}
        {loading ? (
          <View style={s.emptyState}>
            <ActivityIndicator color={C.accent} />
          </View>
        ) : dispensaries.length === 0 ? (
          <View style={s.emptyState}>
            <Text style={s.emptyTitle}>No dispensaries yet</Text>
            <Text style={s.emptyBody}>
              Add the places you shop — their vibe and pricing helps
              CannaGuide make better recommendations.
            </Text>
            <Pressable style={s.emptyBtn} onPress={() => setShowForm(true)}>
              <Text style={s.emptyBtnText}>Add first dispensary</Text>
            </Pressable>
          </View>
        ) : (
          dispensaries.map(d => (
            <DispensaryCard
              key={d.id}
              dispensary={d}
              onDelete={() => handleDelete(d.id, d.name)}
            />
          ))
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 20, paddingTop: Platform.OS === 'ios' ? 60 : 28,
    paddingBottom: 16, borderBottomWidth: 0.5, borderBottomColor: C.border,
    backgroundColor: C.bg,
  },
  headerTitle: { fontFamily: 'Georgia', fontSize: 20, color: C.text, letterSpacing: 0.3 },
  backBtn: { padding: 4 },
  backText: { fontSize: 15, color: C.accent },
  addBtn: { padding: 4 },
  addBtnText: { fontSize: 15, color: C.accent },
  scroll: { flex: 1 },
  scrollContent: { padding: 16, gap: 10 },

  // Form
  form: {
    backgroundColor: C.white, borderRadius: 12, borderWidth: 0.5,
    borderColor: C.border, padding: 16, gap: 12, marginBottom: 4,
  },
  formTitle: {
    fontFamily: 'Georgia', fontSize: 17, color: C.text,
    letterSpacing: 0.2, marginBottom: 4,
  },
  input: {
    fontSize: 15, color: C.text, backgroundColor: C.surface,
    borderRadius: 8, paddingHorizontal: 14, paddingVertical: 11,
    borderWidth: 0.5, borderColor: C.border,
  },
  fieldLabel: {
    fontSize: 12, color: C.muted, letterSpacing: 0.8,
    textTransform: 'uppercase', marginBottom: 6, marginTop: 4,
  },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20,
    borderWidth: 0.5, borderColor: C.border, backgroundColor: C.surface,
  },
  chipActive: { backgroundColor: C.accent, borderColor: C.accent },
  chipDanger: { backgroundColor: C.dangerLt, borderColor: C.danger },
  chipText: { fontSize: 13, color: C.muted },
  chipTextActive: { color: C.white, fontWeight: '500' },
  chipTextDanger: { color: C.danger, fontWeight: '500' },
  saveBtn: {
    backgroundColor: C.accent, borderRadius: 8,
    paddingVertical: 13, alignItems: 'center', marginTop: 4,
  },
  saveBtnText: { color: C.white, fontSize: 15, fontWeight: '500' },

  // Cards
  card: {
    backgroundColor: C.white, borderRadius: 10,
    borderWidth: 0.5, borderColor: C.border, padding: 14, gap: 10,
  },
  cardTop: { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  cardName: { fontFamily: 'Georgia', fontSize: 16, color: C.text, letterSpacing: 0.2 },
  cardCity: { fontSize: 13, color: C.muted, marginTop: 2 },
  cardBadges: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 6 },
  badge: {
    backgroundColor: C.surface, borderRadius: 4,
    paddingHorizontal: 8, paddingVertical: 2,
    borderWidth: 0.5, borderColor: C.border,
  },
  badgeText: { fontSize: 11, color: C.muted },
  cardRatings: { gap: 6 },
  ratingRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  ratingLabel: { fontSize: 12, color: C.muted, width: 36 },
  deleteBtn: { padding: 4 },
  deleteBtnText: { fontSize: 13, color: C.danger },

  // Empty
  emptyState: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
    paddingHorizontal: 32, paddingTop: 60, gap: 12,
  },
  emptyTitle: {
    fontFamily: 'Georgia', fontSize: 20, color: C.text,
    textAlign: 'center', letterSpacing: 0.3,
  },
  emptyBody: { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 21 },
  emptyBtn: {
    marginTop: 8, backgroundColor: C.accent,
    paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8,
  },
  emptyBtnText: { color: C.white, fontSize: 15, fontWeight: '500' },
});

// ─── Wallet widget styles ─────────────────────────────────────────────────────

const w = StyleSheet.create({
  container: {
    borderTopWidth: 0.5, borderTopColor: C.border,
    paddingTop: 10, gap: 8,
  },
  notLinked: {
    borderTopWidth: 0.5, borderTopColor: C.border,
    paddingTop: 10,
  },
  notLinkedText: { fontSize: 12, color: C.light, fontStyle: 'italic' },

  balanceRow: {
    flexDirection: 'row', alignItems: 'center',
    justifyContent: 'space-between',
  },
  pts: { fontSize: 18, fontFamily: 'Georgia', color: C.text, letterSpacing: 0.2 },
  dollarVal: { fontSize: 12, color: C.muted, marginTop: 1 },

  actions: { flexDirection: 'row', gap: 8 },
  actionBtn: {
    paddingHorizontal: 14, paddingVertical: 8,
    borderRadius: 8, alignItems: 'center', justifyContent: 'center', minWidth: 80,
  },
  checkinBtn: { backgroundColor: C.accent },
  redeemBtn: {
    backgroundColor: C.accentLight, borderWidth: 0.5, borderColor: C.accent,
  },
  actionBtnText: { fontSize: 13, color: C.white, fontWeight: '500' },

  redeemRow: { flexDirection: 'row', gap: 8, alignItems: 'center' },
  redeemInput: {
    flex: 1, fontSize: 14, color: C.text, backgroundColor: C.surface,
    borderRadius: 8, paddingHorizontal: 12, paddingVertical: 9,
    borderWidth: 0.5, borderColor: C.border,
  },
});
