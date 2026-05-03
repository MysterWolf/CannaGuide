import React, { useState, useCallback, useEffect } from 'react';
import {
  View, Text, ScrollView, TextInput, Pressable,
  StyleSheet, KeyboardAvoidingView, Platform, Alert, Modal, FlatList,
} from 'react-native';
import { dbRun, dbGetFirst, dbAll, generateUUID, isoNow } from '../db/database';
import { C } from '../theme/colors';
import { CollapsibleSection } from '../components/CollapsibleSection';

const SOURCE_TYPES = [
  { id: 'dispensary', label: 'Dispensary' },
  { id: 'smoke_shop', label: 'Smoke shop' },
  { id: 'delivery',   label: 'Delivery' },
];
const STRAIN_TYPES = [
  { id: 'flower',  label: 'Flower' },
  { id: 'thca',    label: 'THCA' },
  { id: 'hybrid',  label: 'Hybrid' },
  { id: 'indica',  label: 'Indica' },
  { id: 'sativa',  label: 'Sativa' },
  { id: 'cbd',     label: 'CBD' },
];
const METHODS = [
  { id: 'flower',      label: 'Flower' },
  { id: 'vape',        label: 'Vape' },
  { id: 'edible',      label: 'Edible' },
  { id: 'concentrate', label: 'Concentrate' },
  { id: 'tincture',    label: 'Tincture' },
  { id: 'other',       label: 'Other' },
];
const TIMES = [
  { id: 'morning',   label: 'Morning' },
  { id: 'afternoon', label: 'Afternoon' },
  { id: 'evening',   label: 'Evening' },
  { id: 'night',     label: 'Night' },
];
const SETTINGS = [
  { id: 'home',    label: 'Home' },
  { id: 'social',  label: 'Social' },
  { id: 'outdoor', label: 'Outdoor' },
  { id: 'work',    label: 'Work' },
  { id: 'other',   label: 'Other' },
];
const EFFECTS = [
  { key: 'effect_focus',      label: 'Focus',       icon: '◎' },
  { key: 'effect_sleep',      label: 'Sleep',       icon: '◗' },
  { key: 'effect_anxiety',    label: 'Calm',        icon: '◌' },
  { key: 'effect_pain',       label: 'Pain relief', icon: '◈' },
  { key: 'effect_mood',       label: 'Mood',        icon: '◉' },
  { key: 'effect_creativity', label: 'Creativity',  icon: '◆' },
  { key: 'effect_energy',     label: 'Energy',      icon: '◀' },
];
const SIDE_EFFECTS = [
  { key: 'side_dry_mouth', label: 'Dry mouth' },
  { key: 'side_paranoia',  label: 'Paranoia' },
  { key: 'side_headache',  label: 'Headache' },
  { key: 'side_anxiety',   label: 'Anxiety' },
];

type TriState = 'wanted' | 'neutral' | 'unwanted' | null;

function ratingColor(v: number | null) {
  if (!v) return C.border;
  if (v <= 3) return C.danger;
  if (v <= 6) return C.amber;
  return C.sage;
}
function ratingLabel(v: number | null) {
  if (!v) return '—';
  if (v <= 2) return 'Poor';
  if (v <= 4) return 'Low';
  if (v <= 6) return 'OK';
  if (v <= 8) return 'Good';
  return 'Great';
}
function getCurrentTimeOfDay(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return 'morning';
  if (h >= 12 && h < 17) return 'afternoon';
  if (h >= 17 && h < 21) return 'evening';
  return 'night';
}

function strainSummary(name: string, brand: string, strainType: string | null, sourceType: string | null): string | undefined {
  if (!name.trim()) return undefined;
  const parts = [name.trim()];
  if (brand.trim()) parts.push(brand.trim());
  if (strainType)   parts.push(strainType);
  if (sourceType)   parts.push(sourceType.replace('_', ' '));
  return parts.join(' · ');
}
function howSummary(method: string | null, doseNotes: string): string | undefined {
  const parts = [method, doseNotes.trim()].filter(Boolean);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}
function whenSummary(timeOfDay: string | null, setting: string | null): string | undefined {
  const parts = [timeOfDay, setting].filter(Boolean);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}
function overallSummary(rating: number | null): string | undefined {
  if (!rating) return undefined;
  return `${rating}/10 · ${ratingLabel(rating)}`;
}
function effectsSummary(effects: Record<string, number | null>): string | undefined {
  const rated = EFFECTS.filter(e => effects[e.key] != null);
  if (rated.length === 0) return undefined;
  return `${rated.length} of ${EFFECTS.length} rated`;
}
function sideEffectsSummary(sides: Record<string, boolean>): string | undefined {
  const count = Object.values(sides).filter(Boolean).length;
  if (count === 0) return 'None';
  return `${count} noted`;
}
function timingSummary(onset: string, duration: string): string | undefined {
  const parts = [];
  if (onset.trim())    parts.push(`onset ${onset}min`);
  if (duration.trim()) parts.push(`lasted ${duration}min`);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}
function triStateSummary(couch: TriState, hunger: TriState): string | undefined {
  const parts = [];
  if (couch   && couch   !== 'neutral') parts.push(`couch-lock: ${couch}`);
  if (hunger  && hunger  !== 'neutral') parts.push(`hunger: ${hunger}`);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}

function ChipRow({ options, selected, onSelect }: {
  options: {id:string,label:string}[], selected: string|null, onSelect: (id:string)=>void
}) {
  return (
    <View style={s.chipRow}>
      {options.map(opt => (
        <Pressable key={opt.id} onPress={() => onSelect(opt.id)}
          style={[s.chip, selected === opt.id && s.chipActive]}>
          <Text style={[s.chipText, selected === opt.id && s.chipTextActive]}>{opt.label}</Text>
        </Pressable>
      ))}
    </View>
  );
}

function EffectSlider({ label, icon, value, onChange }: {
  label:string, icon:string, value:number|null, onChange:(v:number|null)=>void
}) {
  const color = ratingColor(value);
  return (
    <View style={s.effectRow}>
      <View style={s.effectLabelRow}>
        <Text style={s.effectIcon}>{icon}</Text>
        <Text style={s.effectLabel}>{label}</Text>
        <View style={[s.effectBadge, { backgroundColor: value ? color + '22' : C.surface }]}>
          <Text style={[s.effectBadgeText, { color: value ? color : C.light }]}>
            {ratingLabel(value)}
          </Text>
        </View>
      </View>
      <View style={s.dotsRow}>
        {[1,2,3,4,5,6,7,8,9,10].map(n => (
          <Pressable key={n} onPress={() => onChange(value === n ? null : n)}
            style={[s.dot, {
              backgroundColor: value && n <= value ? color : C.surface,
              borderColor:     value && n <= value ? color : C.border,
              transform: [{ scale: value === n ? 1.25 : 1 }],
            }]} />
        ))}
      </View>
    </View>
  );
}

function TriStateToggle({ label, icon, value, onChange }: {
  label: string, icon: string, value: TriState, onChange: (v: TriState) => void
}) {
  const OPTIONS: { id: TriState; label: string; color: string; bg: string }[] = [
    { id: 'wanted',   label: 'Wanted it',   color: C.sage,   bg: C.sageLt },
    { id: 'neutral',  label: 'Just noticed', color: C.muted,  bg: C.surface },
    { id: 'unwanted', label: 'Unwanted',     color: C.danger, bg: C.dangerLt },
  ];
  return (
    <View style={s.triRow}>
      <View style={s.effectLabelRow}>
        <Text style={s.effectIcon}>{icon}</Text>
        <Text style={s.effectLabel}>{label}</Text>
      </View>
      <View style={s.triOptions}>
        {OPTIONS.map(opt => (
          <Pressable key={opt.id as string}
            onPress={() => onChange(value === opt.id ? null : opt.id)}
            style={[s.triChip,
              value === opt.id && { backgroundColor: opt.bg, borderColor: opt.color }
            ]}>
            <Text style={[s.triChipText, value === opt.id && { color: opt.color }]}>
              {opt.label}
            </Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function SideEffectToggle({ label, value, onChange }: {
  label:string, value:boolean, onChange:(v:boolean)=>void
}) {
  return (
    <Pressable onPress={() => onChange(!value)}
      style={[s.sideChip, value && s.sideChipActive]}>
      <View style={[s.sideCheck, value && s.sideCheckActive]}>
        {value && <Text style={s.sideCheckMark}>✓</Text>}
      </View>
      <Text style={[s.sideChipText, value && s.sideChipTextActive]}>{label}</Text>
    </Pressable>
  );
}

export function LogSessionScreen({ navigation, route }: { navigation: any; route: any }) {
  const sessionId = route?.params?.sessionId as string | undefined;
  const isEdit    = !!sessionId;

  const [strainName,    setStrainName]    = useState('');
  const [brand,         setBrand]         = useState('');
  const [strainType,    setStrainType]    = useState<string|null>(null);
  const [sourceType,    setSourceType]    = useState<string|null>(null);
  const [dispensaryId,  setDispensaryId]  = useState<string|null>(null);
  const [dispensaries,  setDispensaries]  = useState<any[]>([]);
  const [method,        setMethod]        = useState<string|null>(null);
  const [timeOfDay,     setTimeOfDay]     = useState(getCurrentTimeOfDay());
  const [setting,       setSetting]       = useState<string|null>(null);
  const [doseNotes,     setDoseNotes]     = useState('');
  const [overallRating, setOverallRating] = useState<number|null>(null);
  const [effects,       setEffects]       = useState<Record<string,number|null>>({});
  const [couchLock,     setCouchLock]     = useState<TriState>(null);
  const [hunger,        setHunger]        = useState<TriState>(null);
  const [sideEffects,   setSideEffects]   = useState<Record<string,boolean>>({});
  const [durationMins,  setDurationMins]  = useState('');
  const [onsetMins,     setOnsetMins]     = useState('');
  const [notes,         setNotes]         = useState('');
  const [saving,        setSaving]        = useState(false);
  const [loading,       setLoading]       = useState(isEdit);
  const [showDispensaryPicker, setShowDispensaryPicker] = useState(false);
  const [dispensarySearch,     setDispensarySearch]     = useState('');

  useEffect(() => {
    dbAll('SELECT id, name, venue_type FROM dispensaries ORDER BY name ASC')
      .then(setDispensaries)
      .catch(err => console.error('[LogSession] dispensaries:', err));
  }, []);

  useEffect(() => {
    if (!sessionId) return;
    (async () => {
      try {
        const session = await dbGetFirst<any>(
          `SELECT s.*, str.name AS strain_name, str.brand AS strain_brand,
                  str.strain_type AS strain_type_val, str.source_type AS source_type_val
           FROM sessions s
           LEFT JOIN strains str ON str.id = s.strain_id
           WHERE s.id = ?`,
          [sessionId]
        );
        if (!session) return;
        setStrainName(session.strain_name ?? '');
        setBrand(session.strain_brand ?? '');
        setStrainType(session.strain_type_val ?? null);
        setSourceType(session.source_type_val ?? null);
        setDispensaryId(session.dispensary_id ?? null);
        setMethod(session.method ?? null);
        setTimeOfDay(session.time_of_day ?? getCurrentTimeOfDay());
        setSetting(session.setting ?? null);
        setDoseNotes(session.dose_notes ?? '');
        setOverallRating(session.overall_rating ?? null);
        setEffects({
          effect_focus:      session.effect_focus      ?? null,
          effect_sleep:      session.effect_sleep      ?? null,
          effect_anxiety:    session.effect_anxiety    ?? null,
          effect_pain:       session.effect_pain       ?? null,
          effect_mood:       session.effect_mood       ?? null,
          effect_creativity: session.effect_creativity ?? null,
          effect_energy:     session.effect_energy     ?? null,
        });
        setCouchLock(session.couch_lock_intent ?? null);
        setHunger(session.hunger_intent ?? null);
        setSideEffects({
          side_dry_mouth: !!session.side_dry_mouth,
          side_paranoia:  !!session.side_paranoia,
          side_headache:  !!session.side_headache,
          side_anxiety:   !!session.side_anxiety,
        });
        setDurationMins(session.duration_mins?.toString() ?? '');
        setOnsetMins(session.onset_mins?.toString() ?? '');
        setNotes(session.notes ?? '');
      } catch (err: any) {
        Alert.alert('Load failed', err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [sessionId]);

  const handleSave = useCallback(async () => {
    if (!strainName.trim()) {
      Alert.alert('Strain name required', 'Add what you tried before saving.');
      return;
    }
    setSaving(true);
    try {
      let strain = await dbGetFirst<{id:string}>(
        'SELECT id FROM strains WHERE LOWER(name) = LOWER(?) LIMIT 1',
        [strainName.trim()]
      );
      if (!strain) {
        const strainId = generateUUID();
        await dbRun(
          'INSERT INTO strains (id, name, brand, strain_type, source_type, source) VALUES (?,?,?,?,?,?)',
          [strainId, strainName.trim(), brand.trim()||null, strainType, sourceType, 'manual']
        );
        strain = { id: strainId };
      } else {
        await dbRun(
          'UPDATE strains SET strain_type=?, source_type=?, updated_at=? WHERE id=?',
          [strainType, sourceType, isoNow(), strain.id]
        );
      }

      const user = await dbGetFirst<{id:string}>('SELECT id FROM users LIMIT 1');

      if (isEdit && sessionId) {
        await dbRun(
          `UPDATE sessions SET
            strain_id=?, dispensary_id=?, method=?, dose_notes=?, time_of_day=?, setting=?,
            effect_focus=?, effect_sleep=?, effect_anxiety=?, effect_pain=?,
            effect_mood=?, effect_creativity=?, effect_energy=?,
            couch_lock_intent=?, hunger_intent=?,
            overall_rating=?, duration_mins=?, onset_mins=?, notes=?,
            side_dry_mouth=?, side_paranoia=?, side_headache=?, side_anxiety=?,
            updated_at=?
          WHERE id=?`,
          [
            strain.id, dispensaryId??null, method, doseNotes.trim()||null, timeOfDay, setting,
            effects.effect_focus??null, effects.effect_sleep??null,
            effects.effect_anxiety??null, effects.effect_pain??null,
            effects.effect_mood??null, effects.effect_creativity??null,
            effects.effect_energy??null,
            couchLock??null, hunger??null,
            overallRating,
            durationMins ? parseInt(durationMins) : null,
            onsetMins    ? parseInt(onsetMins)    : null,
            notes.trim()||null,
            sideEffects.side_dry_mouth?1:0, sideEffects.side_paranoia?1:0,
            sideEffects.side_headache?1:0, sideEffects.side_anxiety?1:0,
            isoNow(), sessionId,
          ]
        );
      } else {
        const newId = generateUUID();
        await dbRun(
          `INSERT INTO sessions (
            id, user_id, strain_id, dispensary_id, method, dose_notes,
            session_at, time_of_day, setting,
            effect_focus, effect_sleep, effect_anxiety, effect_pain,
            effect_mood, effect_creativity, effect_energy,
            couch_lock_intent, hunger_intent,
            overall_rating, duration_mins, onset_mins, notes,
            side_dry_mouth, side_paranoia, side_headache, side_anxiety
          ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [
            newId, user?.id??null, strain.id, dispensaryId??null,
            method, doseNotes.trim()||null,
            isoNow(), timeOfDay, setting,
            effects.effect_focus??null, effects.effect_sleep??null,
            effects.effect_anxiety??null, effects.effect_pain??null,
            effects.effect_mood??null, effects.effect_creativity??null,
            effects.effect_energy??null,
            couchLock??null, hunger??null,
            overallRating,
            durationMins ? parseInt(durationMins) : null,
            onsetMins    ? parseInt(onsetMins)    : null,
            notes.trim()||null,
            sideEffects.side_dry_mouth?1:0, sideEffects.side_paranoia?1:0,
            sideEffects.side_headache?1:0, sideEffects.side_anxiety?1:0,
          ]
        );
        if (user?.id) {
          await dbRun(
            'UPDATE users SET sessions_since_last_profile = sessions_since_last_profile + 1, updated_at=? WHERE id=?',
            [isoNow(), user.id]
          );
        }
      }
      navigation.goBack();
    } catch (err: any) {
      Alert.alert('Save failed', err.message);
    } finally {
      setSaving(false);
    }
  }, [isEdit, sessionId, strainName, brand, strainType, sourceType, dispensaryId,
      method, timeOfDay, setting, doseNotes, overallRating, effects, couchLock,
      hunger, sideEffects, durationMins, onsetMins, notes]);

  const handleDelete = useCallback(() => {
    Alert.alert('Delete entry', 'This session will be permanently deleted.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => {
        try {
          await dbRun('DELETE FROM sessions WHERE id=?', [sessionId]);
          navigation.goBack();
        } catch (err: any) { Alert.alert('Delete failed', err.message); }
      }},
    ]);
  }, [sessionId, navigation]);

  if (loading) {
    return (
      <View style={[s.root, { alignItems:'center', justifyContent:'center' }]}>
        <Text style={{ fontFamily:'Georgia', fontSize:16, color:C.muted }}>Loading…</Text>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS==='ios'?'padding':'height'}>
      <View style={s.header}>
        <Pressable onPress={() => navigation.goBack()} style={s.cancelBtn}>
          <Text style={s.cancelText}>Cancel</Text>
        </Pressable>
        <Text style={s.headerTitle}>{isEdit ? 'Edit entry' : 'New entry'}</Text>
        <Pressable onPress={handleSave} disabled={saving}
          style={[s.saveBtn, saving && s.saveBtnDisabled]}>
          <Text style={s.saveText}>{saving ? 'Saving…' : isEdit ? 'Update' : 'Save'}</Text>
        </Pressable>
      </View>

      <ScrollView style={s.scroll} contentContainerStyle={s.scrollContent}
        keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>

        <CollapsibleSection title="What did you try?" defaultOpen={true}
          summary={strainSummary(strainName, brand, strainType, sourceType)} required>
          <TextInput style={s.mainInput} placeholder="Strain name"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop: 10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <Text style={[s.subLabel, { marginTop: 14 }]}>Type</Text>
          <ChipRow options={STRAIN_TYPES} selected={strainType} onSelect={setStrainType} />
          <Text style={[s.subLabel, { marginTop: 14 }]}>Where from?</Text>
          <ChipRow options={SOURCE_TYPES} selected={sourceType} onSelect={setSourceType} />
          {dispensaries.length > 0 && (() => {
            const filtered = dispensaries.filter(d =>
              !sourceType || !d.venue_type || d.venue_type === sourceType
            );
            if (filtered.length === 0) return null;
            const selected = filtered.find(d => d.id === dispensaryId);
            return (
              <>
                <Text style={[s.subLabel, { marginTop: 14 }]}>Dispensary</Text>
                <Pressable onPress={() => setShowDispensaryPicker(true)} style={s.pickerBtn}>
                  <Text style={[s.pickerText, !selected && { color: C.light }]}>
                    {selected ? selected.name : 'Select dispensary…'}
                  </Text>
                  <Text style={s.pickerChevron}>›</Text>
                </Pressable>
                {selected && (
                  <Pressable onPress={() => setDispensaryId(null)}>
                    <Text style={{ fontSize:12, color:C.danger, marginTop:4 }}>Clear selection</Text>
                  </Pressable>
                )}
              </>
            );
          })()}
        </CollapsibleSection>

        <CollapsibleSection title="How?" defaultOpen={true} summary={howSummary(method, doseNotes)}>
          <ChipRow options={METHODS} selected={method} onSelect={setMethod} />
          <TextInput style={[s.input, { marginTop: 12 }]}
            placeholder="Dose notes — e.g. 2 hits, 10mg gummy"
            placeholderTextColor={C.light} value={doseNotes} onChangeText={setDoseNotes} />
        </CollapsibleSection>

        <CollapsibleSection title="When and where?" summary={whenSummary(timeOfDay, setting)}>
          <Text style={s.subLabel}>Time of day</Text>
          <ChipRow options={TIMES} selected={timeOfDay} onSelect={setTimeOfDay} />
          <Text style={[s.subLabel, { marginTop: 14 }]}>Setting</Text>
          <ChipRow options={SETTINGS} selected={setting} onSelect={setSetting} />
        </CollapsibleSection>

        <CollapsibleSection title="Overall?" summary={overallSummary(overallRating)}>
          <View style={s.overallRow}>
            {[1,2,3,4,5,6,7,8,9,10].map(n => (
              <Pressable key={n}
                onPress={() => setOverallRating(overallRating===n?null:n)}
                style={[s.overallDot, {
                  backgroundColor: overallRating&&n<=overallRating ? ratingColor(overallRating) : C.surface,
                  borderColor:     overallRating&&n<=overallRating ? ratingColor(overallRating) : C.border,
                  transform: [{ scale: overallRating===n?1.3:1 }],
                }]}>
                {overallRating===n && <Text style={s.overallNum}>{n}</Text>}
              </Pressable>
            ))}
          </View>
          {overallRating && (
            <Text style={[s.ratingWord, { color: ratingColor(overallRating) }]}>
              {ratingLabel(overallRating)} session
            </Text>
          )}
        </CollapsibleSection>

        <CollapsibleSection title="Effects felt" summary={effectsSummary(effects)}>
          <Text style={s.effectHint}>Tap a dot to rate. Tap again to clear.</Text>
          {EFFECTS.map(e => (
            <EffectSlider key={e.key} label={e.label} icon={e.icon}
              value={effects[e.key]??null}
              onChange={val => setEffects(prev => ({ ...prev, [e.key]: val }))} />
          ))}
          <View style={s.triDivider} />
          <Text style={[s.subLabel, { marginBottom: 10 }]}>Ambiguous effects</Text>
          <TriStateToggle label="Couch-lock" icon="◐"
            value={couchLock} onChange={setCouchLock} />
          <TriStateToggle label="Hunger / munchies" icon="◑"
            value={hunger} onChange={setHunger} />
        </CollapsibleSection>

        <CollapsibleSection title="Side effects" summary={sideEffectsSummary(sideEffects)}>
          <Text style={s.effectHint}>Unwanted effects only — paranoia, headache, anxiety, dry mouth.</Text>
          <View style={s.sideRow}>
            {SIDE_EFFECTS.map(se => (
              <SideEffectToggle key={se.key} label={se.label}
                value={!!sideEffects[se.key]}
                onChange={val => setSideEffects(prev => ({ ...prev, [se.key]: val }))} />
            ))}
          </View>
        </CollapsibleSection>

        <CollapsibleSection title="Timing" summary={timingSummary(onsetMins, durationMins)}>
          <View style={s.timingRow}>
            <View style={s.timingField}>
              <Text style={s.subLabel}>Felt it after</Text>
              <View style={s.timingInputRow}>
                <TextInput style={s.timingInput} placeholder="—"
                  placeholderTextColor={C.light} value={onsetMins}
                  onChangeText={t => setOnsetMins(t.replace(/\D/g,''))}
                  keyboardType="number-pad" maxLength={3} />
                <Text style={s.timingUnit}>min</Text>
              </View>
            </View>
            <View style={s.timingField}>
              <Text style={s.subLabel}>Lasted about</Text>
              <View style={s.timingInputRow}>
                <TextInput style={s.timingInput} placeholder="—"
                  placeholderTextColor={C.light} value={durationMins}
                  onChangeText={t => setDurationMins(t.replace(/\D/g,''))}
                  keyboardType="number-pad" maxLength={3} />
                <Text style={s.timingUnit}>min</Text>
              </View>
            </View>
          </View>
        </CollapsibleSection>

        <CollapsibleSection title="Journal notes"
          summary={notes.trim() ? notes.trim().slice(0,40) + (notes.length>40?'…':'') : undefined}>
          <TextInput style={s.notesInput}
            placeholder="How did it feel? What were you doing? Anything worth remembering…"
            placeholderTextColor={C.light} value={notes} onChangeText={setNotes}
            multiline textAlignVertical="top" />
        </CollapsibleSection>

        {isEdit && (
          <View style={{ paddingHorizontal:24, paddingTop:16 }}>
            <Pressable onPress={handleDelete} style={s.deleteBtn}>
              <Text style={s.deleteBtnText}>Delete this entry</Text>
            </Pressable>
          </View>
        )}

        <View style={{ height:48 }} />
      </ScrollView>

      <Modal visible={showDispensaryPicker} animationType="slide"
        presentationStyle="pageSheet" onRequestClose={() => setShowDispensaryPicker(false)}>
        <View style={s.modalRoot}>
          <View style={s.modalHeader}>
            <Text style={s.modalTitle}>Select dispensary</Text>
            <Pressable onPress={() => setShowDispensaryPicker(false)}>
              <Text style={{ fontSize:15, color:C.accent }}>Done</Text>
            </Pressable>
          </View>
          <TextInput style={s.modalSearch} placeholder="Search…"
            placeholderTextColor={C.light} value={dispensarySearch}
            onChangeText={setDispensarySearch} autoFocus />
          <FlatList
            data={dispensaries.filter(d => {
              const matchesType   = !sourceType || !d.venue_type || d.venue_type === sourceType;
              const matchesSearch = d.name.toLowerCase().includes(dispensarySearch.toLowerCase());
              return matchesType && matchesSearch;
            })}
            keyExtractor={item => item.id}
            renderItem={({ item }) => (
              <Pressable onPress={() => {
                setDispensaryId(item.id);
                setDispensarySearch('');
                setShowDispensaryPicker(false);
              }} style={[s.modalItem, dispensaryId===item.id && s.modalItemActive]}>
                <View style={{ flex:1 }}>
                  <Text style={[s.modalItemName, dispensaryId===item.id && { color:C.accent }]}>
                    {item.name}
                  </Text>
                  {item.venue_type && (
                    <Text style={s.modalItemSub}>{item.venue_type.replace('_',' ')}</Text>
                  )}
                </View>
                {dispensaryId===item.id && <Text style={{ fontSize:18, color:C.accent }}>✓</Text>}
              </Pressable>
            )}
            ListEmptyComponent={
              <View style={{ padding:24, alignItems:'center' }}>
                <Text style={{ fontSize:14, color:C.muted }}>No matching dispensaries</Text>
              </View>
            }
          />
        </View>
      </Modal>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex:1, backgroundColor:C.bg },
  header: { flexDirection:'row', alignItems:'center', justifyContent:'space-between',
    paddingHorizontal:20, paddingTop:Platform.OS==='ios'?56:24, paddingBottom:16,
    backgroundColor:C.bg, borderBottomWidth:0.5, borderBottomColor:C.border },
  headerTitle: { fontFamily:'Georgia', fontSize:18, color:C.text, letterSpacing:0.3 },
  cancelBtn: { padding:4 },
  cancelText: { fontSize:15, color:C.muted },
  saveBtn: { backgroundColor:C.accent, paddingHorizontal:16, paddingVertical:7, borderRadius:6 },
  saveBtnDisabled: { opacity:0.5 },
  saveText: { color:C.white, fontSize:14, fontWeight:'500' },
  scroll: { flex:1 },
  scrollContent: { paddingTop:8, paddingBottom:8 },
  subLabel: { fontSize:12, color:C.muted, letterSpacing:0.8, textTransform:'uppercase', marginBottom:8 },
  mainInput: { fontFamily:'Georgia', fontSize:22, color:C.text, borderBottomWidth:1,
    borderBottomColor:C.border, paddingBottom:10, letterSpacing:0.3 },
  input: { fontSize:15, color:C.text, backgroundColor:C.surface, borderRadius:8,
    paddingHorizontal:14, paddingVertical:11, borderWidth:0.5, borderColor:C.border },
  notesInput: { fontSize:15, color:C.text, backgroundColor:C.surface, borderRadius:8,
    paddingHorizontal:14, paddingVertical:14, borderWidth:0.5, borderColor:C.border,
    minHeight:110, lineHeight:22 },
  chipRow: { flexDirection:'row', flexWrap:'wrap', gap:8 },
  chip: { paddingHorizontal:14, paddingVertical:8, borderRadius:20, borderWidth:0.5,
    borderColor:C.border, backgroundColor:C.surface },
  chipActive: { backgroundColor:C.accent, borderColor:C.accent },
  chipText: { fontSize:13, color:C.muted },
  chipTextActive: { color:C.white, fontWeight:'500' },
  overallRow: { flexDirection:'row', gap:6, alignItems:'center' },
  overallDot: { width:28, height:28, borderRadius:14, borderWidth:0.5,
    alignItems:'center', justifyContent:'center' },
  overallNum: { fontSize:10, color:C.white, fontWeight:'600' },
  ratingWord: { marginTop:10, fontSize:13, fontFamily:'Georgia', letterSpacing:0.2 },
  effectHint: { fontSize:12, color:C.light, marginBottom:16, lineHeight:18 },
  effectRow: { marginBottom:18 },
  effectLabelRow: { flexDirection:'row', alignItems:'center', gap:8, marginBottom:8 },
  effectIcon: { fontSize:14, color:C.muted, width:20 },
  effectLabel: { fontSize:14, color:C.text, flex:1 },
  effectBadge: { paddingHorizontal:8, paddingVertical:2, borderRadius:4 },
  effectBadgeText: { fontSize:11, fontWeight:'500' },
  dotsRow: { flexDirection:'row', gap:6, paddingLeft:28 },
  dot: { width:22, height:22, borderRadius:11, borderWidth:0.5 },
  triDivider: { height:0.5, backgroundColor:C.border, marginVertical:16 },
  triRow: { marginBottom:16 },
  triOptions: { flexDirection:'row', gap:8, paddingLeft:28, flexWrap:'wrap' },
  triChip: { paddingHorizontal:12, paddingVertical:7, borderRadius:8, borderWidth:0.5,
    borderColor:C.border, backgroundColor:C.surface },
  triChipText: { fontSize:12, color:C.muted },
  sideRow: { flexDirection:'row', flexWrap:'wrap', gap:8 },
  sideChip: { flexDirection:'row', alignItems:'center', gap:6, paddingHorizontal:12,
    paddingVertical:8, borderRadius:6, borderWidth:0.5, borderColor:C.border, backgroundColor:C.surface },
  sideChipActive: { backgroundColor:C.dangerLt, borderColor:C.danger },
  sideCheck: { width:16, height:16, borderRadius:4, borderWidth:0.5, borderColor:C.border,
    alignItems:"center", justifyContent:"center", backgroundColor:C.bg },
  sideCheckActive: { backgroundColor:C.danger, borderColor:C.danger },
  sideCheckMark: { color:C.white, fontSize:10, fontWeight:'700' },
  sideChipText: { fontSize:13, color:C.muted },
  sideChipTextActive: { color:C.danger },
  timingRow: { flexDirection:'row', gap:16 },
  timingField: { flex:1 },
  timingInputRow: { flexDirection:'row', alignItems:'center', gap:8 },
  timingInput: { flex:1, fontSize:20, fontFamily:'Georgia', color:C.text,
    backgroundColor:C.surface, borderRadius:8, paddingHorizontal:14, paddingVertical:11,
    borderWidth:0.5, borderColor:C.border, textAlign:'center' },
  timingUnit: { fontSize:13, color:C.muted },
  pickerBtn: { flexDirection:'row', alignItems:'center', justifyContent:'space-between',
    backgroundColor:C.surface, borderRadius:8, borderWidth:0.5, borderColor:C.border,
    paddingHorizontal:14, paddingVertical:12 },
  pickerText: { fontSize:15, color:C.text, flex:1 },
  pickerChevron: { fontSize:20, color:C.muted },
  deleteBtn: { padding:14, borderRadius:8, borderWidth:0.5, borderColor:C.danger, alignItems:'center' },
  deleteBtnText: { fontSize:15, color:C.danger, fontWeight:'500' },
  modalRoot: { flex:1, backgroundColor:C.bg },
  modalHeader: { flexDirection:'row', alignItems:'center', justifyContent:'space-between',
    paddingHorizontal:20, paddingTop:20, paddingBottom:12,
    borderBottomWidth:0.5, borderBottomColor:C.border },
  modalTitle: { fontFamily:'Georgia', fontSize:18, color:C.text },
  modalSearch: { margin:16, backgroundColor:C.surface, borderRadius:8, borderWidth:0.5,
    borderColor:C.border, paddingHorizontal:14, paddingVertical:11, fontSize:15, color:C.text },
  modalItem: { flexDirection:'row', alignItems:'center', paddingHorizontal:20, paddingVertical:14,
    borderBottomWidth:0.5, borderBottomColor:C.border },
  modalItemActive: { backgroundColor:C.accentLight },
  modalItemName: { fontSize:16, color:C.text, fontFamily:'Georgia' },
  modalItemSub: { fontSize:12, color:C.muted, marginTop:2 },
});
