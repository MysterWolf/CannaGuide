import React, { useState, useCallback, useEffect } from 'react';
import {
  View, Text, ScrollView, TextInput, Pressable,
  StyleSheet, KeyboardAvoidingView, Platform, Alert, Modal, FlatList,
} from 'react-native';
import { dbRun, dbGetFirst, dbAll, generateUUID, isoNow } from '../db/database';
import { C } from '../theme/colors';
import { CollapsibleSection } from '../components/CollapsibleSection';

// ── Constants ────────────────────────────────────────────────────────────────

const PRODUCT_CATEGORIES = [
  { id: 'flower',       label: 'Flower',        emoji: '🌿' },
  { id: 'edibles',      label: 'Edibles',        emoji: '🍬' },
  { id: 'beverages',    label: 'THC Beverages',  emoji: '🥤' },
  { id: 'vapes',        label: 'Vapes',          emoji: '💨' },
  { id: 'tinctures',    label: 'Tinctures',      emoji: '🧪' },
  { id: 'topicals',     label: 'Topicals',       emoji: '🫧' },
  { id: 'concentrates', label: 'Concentrates',   emoji: '💎' },
];

const FLOWER_TYPES    = [{ id:'sativa',   label:'Sativa' }, { id:'hybrid', label:'Hybrid' }, { id:'indica', label:'Indica' }];
const FLOWER_METHODS  = [{ id:'joint',    label:'Joint' }, { id:'pipe', label:'Pipe' }, { id:'bong', label:'Bong' }, { id:'vaporizer', label:'Vaporizer' }];
const BEV_TYPES       = [{ id:'seltzer',  label:'Seltzer' }, { id:'shot', label:'Shot' }, { id:'tonic', label:'Tonic' }, { id:'wine', label:'Non-alc. wine' }];
const BEV_INGREDIENTS = ["Lion's Mane", 'CBN', 'CBD', 'Cordyceps', 'Caffeine'];
const BEV_USE_CASES   = [{ id:'social',  label:'Social' }, { id:'sleep', label:'Sleep' }, { id:'focus', label:'Focus' }, { id:'relax', label:'Relax' }, { id:'energy', label:'Energy' }];
const VAPE_TYPES      = [{ id:'cartridge', label:'Cartridge' }, { id:'disposable', label:'Disposable' }];
const CONCENTRATE_TYPES   = [{ id:'wax', label:'Wax' }, { id:'shatter', label:'Shatter' }, { id:'rosin', label:'Rosin' }, { id:'badder', label:'Badder' }, { id:'live_resin', label:'Live resin' }];
const CONCENTRATE_METHODS = [{ id:'dab_rig', label:'Dab rig' }, { id:'dab_pen', label:'Dab pen' }];
const TOPICAL_PURPOSES    = [{ id:'pain', label:'Pain relief' }, { id:'inflammation', label:'Inflammation' }, { id:'skin', label:'Skin care' }];
const SOURCE_TYPES = [{ id:'dispensary', label:'Dispensary' }, { id:'smoke_shop', label:'Smoke shop' }, { id:'delivery', label:'Delivery' }];
const TIMES    = [{ id:'morning', label:'Morning' }, { id:'afternoon', label:'Afternoon' }, { id:'evening', label:'Evening' }, { id:'night', label:'Night' }];
const SETTINGS = [{ id:'home', label:'Home' }, { id:'social', label:'Social' }, { id:'outdoor', label:'Outdoor' }, { id:'work', label:'Work' }, { id:'other', label:'Other' }];
const EFFECTS  = [
  { key:'effect_focus',      label:'Focus',       icon:'◎' },
  { key:'effect_sleep',      label:'Sleep',       icon:'◗' },
  { key:'effect_anxiety',    label:'Calm',        icon:'◌' },
  { key:'effect_pain',       label:'Pain relief', icon:'◈' },
  { key:'effect_mood',       label:'Mood',        icon:'◉' },
  { key:'effect_creativity', label:'Creativity',  icon:'◆' },
  { key:'effect_energy',     label:'Energy',      icon:'◀' },
];
const SIDE_EFFECTS = [
  { key:'side_dry_mouth', label:'Dry mouth' },
  { key:'side_paranoia',  label:'Paranoia' },
  { key:'side_headache',  label:'Headache' },
  { key:'side_anxiety',   label:'Anxiety' },
];

type TriState = 'wanted' | 'neutral' | 'unwanted' | null;

// ── Helpers ──────────────────────────────────────────────────────────────────

function ratingColor(v: number | null) {
  if (!v) return C.border;
  if (v <= 2) return C.danger;
  if (v <= 3) return C.amber;
  return C.sage;
}
function ratingLabel(v: number | null) {
  if (!v) return '—';
  return ['', 'Poor', 'Low', 'OK', 'Good', 'Great'][v] ?? '—';
}
function getCurrentTimeOfDay(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return 'morning';
  if (h >= 12 && h < 17) return 'afternoon';
  if (h >= 17 && h < 21) return 'evening';
  return 'night';
}
function productSummary(cat: string | null, name: string, brand: string, flavor: string): string | undefined {
  if (!cat) return undefined;
  if (cat === 'beverages') {
    const parts = [brand.trim(), flavor.trim()].filter(Boolean);
    return parts.length > 0 ? parts.join(' · ') : undefined;
  }
  if (!name.trim()) return undefined;
  return brand.trim() ? `${name.trim()} · ${brand.trim()}` : name.trim();
}
function whereFromSummary(source: string | null, dispensaries: any[], dispensaryId: string | null): string | undefined {
  const parts: string[] = [];
  if (source) parts.push(source.replace('_', ' '));
  if (dispensaryId) {
    const d = dispensaries.find(x => x.id === dispensaryId);
    if (d) parts.push(d.name);
  }
  return parts.length > 0 ? parts.join(' · ') : undefined;
}
function whenSummary(timeOfDay: string | null, setting: string | null): string | undefined {
  return [timeOfDay, setting].filter(Boolean).join(' · ') || undefined;
}
function overallSummary(rating: number | null): string | undefined {
  if (!rating) return undefined;
  return '★'.repeat(rating) + '☆'.repeat(5 - rating);
}
function effectsSummary(effects: Record<string, number | null>): string | undefined {
  const count = EFFECTS.filter(e => effects[e.key] != null).length;
  return count > 0 ? `${count} of ${EFFECTS.length} rated` : undefined;
}
function sideEffectsSummary(sides: Record<string, boolean>): string | undefined {
  const count = Object.values(sides).filter(Boolean).length;
  return count === 0 ? 'None' : `${count} noted`;
}
function timingSummary(onset: string, duration: string): string | undefined {
  const parts: string[] = [];
  if (onset.trim())    parts.push(`onset ${onset}min`);
  if (duration.trim()) parts.push(`lasted ${duration}min`);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}
function triStateSummary(couch: TriState, hunger: TriState): string | undefined {
  const parts: string[] = [];
  if (couch  && couch  !== 'neutral') parts.push(`couch-lock: ${couch}`);
  if (hunger && hunger !== 'neutral') parts.push(`hunger: ${hunger}`);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}

// ── UI components ─────────────────────────────────────────────────────────────

function ChipRow({ options, selected, onSelect }: {
  options: {id:string,label:string}[], selected: string|null, onSelect: (id:string|null)=>void
}) {
  return (
    <View style={s.chipRow}>
      {options.map(opt => (
        <Pressable key={opt.id} onPress={() => onSelect(selected === opt.id ? null : opt.id)}
          style={[s.chip, selected === opt.id && s.chipActive]}>
          <Text style={[s.chipText, selected === opt.id && s.chipTextActive]}>{opt.label}</Text>
        </Pressable>
      ))}
    </View>
  );
}

function MultiChipRow({ options, selected, onToggle }: {
  options: string[], selected: string[], onToggle: (opt:string)=>void
}) {
  return (
    <View style={s.chipRow}>
      {options.map(opt => (
        <Pressable key={opt} onPress={() => onToggle(opt)}
          style={[s.chip, selected.includes(opt) && s.chipActive]}>
          <Text style={[s.chipText, selected.includes(opt) && s.chipTextActive]}>{opt}</Text>
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
  label:string, icon:string, value:TriState, onChange:(v:TriState)=>void
}) {
  const OPTIONS: {id:TriState;label:string;color:string;bg:string}[] = [
    { id:'wanted',   label:'Wanted it',    color:C.sage,   bg:C.sageLt },
    { id:'neutral',  label:'Just noticed', color:C.muted,  bg:C.surface },
    { id:'unwanted', label:'Unwanted',     color:C.danger, bg:C.dangerLt },
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
            style={[s.triChip, value === opt.id && { backgroundColor:opt.bg, borderColor:opt.color }]}>
            <Text style={[s.triChipText, value === opt.id && { color:opt.color }]}>{opt.label}</Text>
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

// ── Screen ────────────────────────────────────────────────────────────────────

export function LogSessionScreen({ navigation, route }: { navigation:any; route:any }) {
  const sessionId = route?.params?.sessionId as string | undefined;
  const isEdit    = !!sessionId;

  // Shared state
  const [productCategory,       setProductCategory]       = useState<string|null>(null);
  const [strainName,            setStrainName]            = useState('');
  const [brand,                 setBrand]                 = useState('');
  const [strainType,            setStrainType]            = useState<string|null>(null); // flower: sativa/hybrid/indica
  const [method,                setMethod]                = useState<string|null>(null); // flower/concentrate delivery
  const [doseNotes,             setDoseNotes]             = useState('');
  const [sourceType,            setSourceType]            = useState<string|null>(null);
  const [dispensaryId,          setDispensaryId]          = useState<string|null>(null);
  const [dispensaries,          setDispensaries]          = useState<any[]>([]);
  const [timeOfDay,             setTimeOfDay]             = useState(getCurrentTimeOfDay());
  const [setting,               setSetting]               = useState<string|null>(null);
  const [overallRating,         setOverallRating]         = useState<number|null>(null);
  const [effects,               setEffects]               = useState<Record<string,number|null>>({});
  const [couchLock,             setCouchLock]             = useState<TriState>(null);
  const [hunger,                setHunger]                = useState<TriState>(null);
  const [sideEffects,           setSideEffects]           = useState<Record<string,boolean>>({});
  const [durationMins,          setDurationMins]          = useState('');
  const [onsetMins,             setOnsetMins]             = useState('');
  const [notes,                 setNotes]                 = useState('');

  // Category-specific state
  const [mgThc,                 setMgThc]                 = useState('');
  const [mgCbd,                 setMgCbd]                 = useState('');
  const [productType,           setProductType]           = useState<string|null>(null);
  const [productFlavor,         setProductFlavor]         = useState('');
  const [functionalIngredients, setFunctionalIngredients] = useState<string[]>([]);
  const [useCase,               setUseCase]               = useState<string|null>(null);

  const [saving,  setSaving]  = useState(false);
  const [loading, setLoading] = useState(isEdit);
  const [showDispensaryPicker,  setShowDispensaryPicker]  = useState(false);
  const [dispensarySearch,      setDispensarySearch]      = useState('');

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
        setProductCategory(session.product_category ?? null);
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
        setMgThc(session.mg_thc?.toString() ?? '');
        setMgCbd(session.mg_cbd?.toString() ?? '');
        setProductType(session.product_type ?? null);
        setProductFlavor(session.product_flavor ?? '');
        setFunctionalIngredients(session.functional_ingredients
          ? JSON.parse(session.functional_ingredients) : []);
        setUseCase(session.use_case ?? null);
        setBrand(session.strain_brand ?? '');
        if (session.product_category !== 'beverages') {
          setStrainName(session.strain_name ?? '');
        }
      } catch (err: any) {
        Alert.alert('Load failed', err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [sessionId]);

  const handleSave = useCallback(async () => {
    if (!productCategory) {
      Alert.alert('Select a category', 'Choose what type of product you tried.');
      return;
    }
    if (productCategory === 'beverages') {
      if (!brand.trim() && !productFlavor.trim()) {
        Alert.alert('Brand or flavor required', 'Add at least a brand or flavor to identify this product.');
        return;
      }
    } else if (!strainName.trim()) {
      Alert.alert('Name required', 'Add the product name before saving.');
      return;
    }

    setSaving(true);
    try {
      const productName = productCategory === 'beverages'
        ? [brand.trim(), productFlavor.trim()].filter(Boolean).join(' ') || 'THC Beverage'
        : strainName.trim();
      const strainTypeForDb = productCategory === 'flower' ? strainType : productCategory;
      const ingredientsJson = functionalIngredients.length > 0
        ? JSON.stringify(functionalIngredients)
        : null;

      let strain = await dbGetFirst<{id:string}>(
        'SELECT id FROM strains WHERE LOWER(name) = LOWER(?) LIMIT 1',
        [productName]
      );
      if (!strain) {
        const strainId = generateUUID();
        await dbRun(
          'INSERT INTO strains (id, name, brand, strain_type, source_type, source) VALUES (?,?,?,?,?,?)',
          [strainId, productName, brand.trim()||null, strainTypeForDb, sourceType, 'manual']
        );
        strain = { id: strainId };
      } else {
        await dbRun(
          'UPDATE strains SET brand=?, strain_type=?, source_type=?, updated_at=? WHERE id=?',
          [brand.trim()||null, strainTypeForDb, sourceType, isoNow(), strain.id]
        );
      }

      const user = await dbGetFirst<{id:string}>('SELECT id FROM users LIMIT 1');

      if (isEdit && sessionId) {
        await dbRun(
          `UPDATE sessions SET
            strain_id=?, dispensary_id=?,
            product_category=?, method=?, dose_notes=?, time_of_day=?, setting=?,
            effect_focus=?, effect_sleep=?, effect_anxiety=?, effect_pain=?,
            effect_mood=?, effect_creativity=?, effect_energy=?,
            couch_lock_intent=?, hunger_intent=?,
            overall_rating=?, duration_mins=?, onset_mins=?, notes=?,
            side_dry_mouth=?, side_paranoia=?, side_headache=?, side_anxiety=?,
            mg_thc=?, mg_cbd=?, product_type=?, product_flavor=?,
            functional_ingredients=?, use_case=?,
            updated_at=?
          WHERE id=?`,
          [
            strain.id, dispensaryId??null,
            productCategory, method??null, doseNotes.trim()||null, timeOfDay, setting??null,
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
            mgThc ? parseFloat(mgThc) : null,
            mgCbd ? parseFloat(mgCbd) : null,
            productType??null, productFlavor.trim()||null,
            ingredientsJson, useCase??null,
            isoNow(), sessionId,
          ]
        );
      } else {
        const newId = generateUUID();
        await dbRun(
          `INSERT INTO sessions (
            id, user_id, strain_id, dispensary_id,
            product_category, method, dose_notes,
            session_at, time_of_day, setting,
            effect_focus, effect_sleep, effect_anxiety, effect_pain,
            effect_mood, effect_creativity, effect_energy,
            couch_lock_intent, hunger_intent,
            overall_rating, duration_mins, onset_mins, notes,
            side_dry_mouth, side_paranoia, side_headache, side_anxiety,
            mg_thc, mg_cbd, product_type, product_flavor,
            functional_ingredients, use_case
          ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [
            newId, user?.id??null, strain.id, dispensaryId??null,
            productCategory, method??null, doseNotes.trim()||null,
            isoNow(), timeOfDay, setting??null,
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
            mgThc ? parseFloat(mgThc) : null,
            mgCbd ? parseFloat(mgCbd) : null,
            productType??null, productFlavor.trim()||null,
            ingredientsJson, useCase??null,
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
  }, [
    isEdit, sessionId, productCategory, strainName, brand, strainType, sourceType,
    dispensaryId, method, timeOfDay, setting, doseNotes, overallRating, effects,
    couchLock, hunger, sideEffects, durationMins, onsetMins, notes,
    mgThc, mgCbd, productType, productFlavor, functionalIngredients, useCase,
  ]);

  const handleDelete = useCallback(() => {
    Alert.alert('Delete entry', 'This session will be permanently deleted.', [
      { text:'Cancel', style:'cancel' },
      { text:'Delete', style:'destructive', onPress: async () => {
        try {
          await dbRun('DELETE FROM sessions WHERE id=?', [sessionId]);
          navigation.goBack();
        } catch (err:any) { Alert.alert('Delete failed', err.message); }
      }},
    ]);
  }, [sessionId, navigation]);

  const catInfo = PRODUCT_CATEGORIES.find(c => c.id === productCategory);

  function renderProductFields() {
    switch (productCategory) {
      case 'flower': return (
        <>
          <TextInput style={s.mainInput} placeholder="Strain name *"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <Text style={[s.subLabel, { marginTop:14 }]}>Type</Text>
          <ChipRow options={FLOWER_TYPES} selected={strainType} onSelect={setStrainType} />
          <Text style={[s.subLabel, { marginTop:14 }]}>Method</Text>
          <ChipRow options={FLOWER_METHODS} selected={method} onSelect={setMethod} />
          <TextInput style={[s.input, { marginTop:14 }]}
            placeholder="Amount (e.g. 2 hits, 0.5g)"
            placeholderTextColor={C.light} value={doseNotes} onChangeText={setDoseNotes} />
        </>
      );

      case 'beverages': return (
        <>
          <TextInput style={s.mainInput} placeholder="Brand *"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Flavor (optional)"
            placeholderTextColor={C.light} value={productFlavor}
            onChangeText={setProductFlavor} autoCapitalize="words" />
          <Text style={[s.subLabel, { marginTop:14 }]}>Product type</Text>
          <ChipRow options={BEV_TYPES} selected={productType} onSelect={setProductType} />
          <View style={[s.mgRow, { marginTop:14 }]}>
            <View style={s.mgField}>
              <Text style={s.subLabel}>mg THC</Text>
              <TextInput style={s.mgInput} value={mgThc} onChangeText={setMgThc}
                keyboardType="decimal-pad" placeholder="0" placeholderTextColor={C.light} />
            </View>
          </View>
          <Text style={[s.subLabel, { marginTop:14 }]}>Functional ingredients</Text>
          <MultiChipRow options={BEV_INGREDIENTS} selected={functionalIngredients}
            onToggle={opt => setFunctionalIngredients(prev =>
              prev.includes(opt) ? prev.filter(i => i !== opt) : [...prev, opt])} />
          <Text style={[s.subLabel, { marginTop:14 }]}>Use case</Text>
          <ChipRow options={BEV_USE_CASES} selected={useCase} onSelect={setUseCase} />
        </>
      );

      case 'edibles': return (
        <>
          <TextInput style={s.mainInput} placeholder="Product name *"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <View style={[s.mgRow, { marginTop:14 }]}>
            <View style={s.mgField}>
              <Text style={s.subLabel}>mg THC</Text>
              <TextInput style={s.mgInput} value={mgThc} onChangeText={setMgThc}
                keyboardType="decimal-pad" placeholder="0" placeholderTextColor={C.light} />
            </View>
            <View style={s.mgField}>
              <Text style={s.subLabel}>mg CBD</Text>
              <TextInput style={s.mgInput} value={mgCbd} onChangeText={setMgCbd}
                keyboardType="decimal-pad" placeholder="0" placeholderTextColor={C.light} />
            </View>
          </View>
        </>
      );

      case 'vapes': return (
        <>
          <TextInput style={s.mainInput} placeholder="Strain / product name *"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <Text style={[s.subLabel, { marginTop:14 }]}>Type</Text>
          <ChipRow options={VAPE_TYPES} selected={productType} onSelect={setProductType} />
        </>
      );

      case 'tinctures': return (
        <>
          <TextInput style={s.mainInput} placeholder="Product name *"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <View style={[s.mgRow, { marginTop:14 }]}>
            <View style={s.mgField}>
              <Text style={s.subLabel}>mg CBD</Text>
              <TextInput style={s.mgInput} value={mgCbd} onChangeText={setMgCbd}
                keyboardType="decimal-pad" placeholder="0" placeholderTextColor={C.light} />
            </View>
            <View style={s.mgField}>
              <Text style={s.subLabel}>mg THC</Text>
              <TextInput style={s.mgInput} value={mgThc} onChangeText={setMgThc}
                keyboardType="decimal-pad" placeholder="0" placeholderTextColor={C.light} />
            </View>
          </View>
          <TextInput style={[s.input, { marginTop:14 }]}
            placeholder="Serving (e.g. 1 dropper, 0.5ml)"
            placeholderTextColor={C.light} value={doseNotes} onChangeText={setDoseNotes} />
        </>
      );

      case 'topicals': return (
        <>
          <TextInput style={s.mainInput} placeholder="Product name *"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]}
            placeholder="Application area (e.g. lower back, knee)"
            placeholderTextColor={C.light} value={doseNotes} onChangeText={setDoseNotes} />
          <Text style={[s.subLabel, { marginTop:14 }]}>Purpose</Text>
          <ChipRow options={TOPICAL_PURPOSES} selected={productType} onSelect={setProductType} />
        </>
      );

      case 'concentrates': return (
        <>
          <TextInput style={s.mainInput} placeholder="Strain name *"
            placeholderTextColor={C.light} value={strainName}
            onChangeText={setStrainName} autoCapitalize="words" />
          <TextInput style={[s.input, { marginTop:10 }]} placeholder="Brand (optional)"
            placeholderTextColor={C.light} value={brand}
            onChangeText={setBrand} autoCapitalize="words" />
          <Text style={[s.subLabel, { marginTop:14 }]}>Type</Text>
          <ChipRow options={CONCENTRATE_TYPES} selected={productType} onSelect={setProductType} />
          <Text style={[s.subLabel, { marginTop:14 }]}>Method</Text>
          <ChipRow options={CONCENTRATE_METHODS} selected={method} onSelect={setMethod} />
          <TextInput style={[s.input, { marginTop:14 }]}
            placeholder="Amount (e.g. 0.1g dab)"
            placeholderTextColor={C.light} value={doseNotes} onChangeText={setDoseNotes} />
        </>
      );

      default: return null;
    }
  }

  if (loading) {
    return (
      <View style={[s.root, { alignItems:'center', justifyContent:'center' }]}>
        <Text style={{ fontFamily:'Georgia', fontSize:16, color:C.muted }}>Loading…</Text>
      </View>
    );
  }

  const selectedDispensary = dispensaries.find(d => d.id === dispensaryId);

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

        {/* Category picker */}
        <View style={s.categorySection}>
          <Text style={s.categorySectionLabel}>Category <Text style={{ color:C.danger }}>*</Text></Text>
          <View style={s.categoryGrid}>
            {PRODUCT_CATEGORIES.map(cat => (
              <Pressable key={cat.id}
                onPress={() => {
                  setProductCategory(cat.id === productCategory ? null : cat.id);
                  setProductType(null);
                  setMethod(null);
                  setStrainType(null);
                }}
                style={[
                  s.categoryChip,
                  productCategory === cat.id && s.categoryChipActive,
                ]}>
                <Text style={s.categoryEmoji}>{cat.emoji}</Text>
                <Text style={[s.categoryChipLabel, productCategory === cat.id && s.categoryChipLabelActive]}>
                  {cat.label}
                </Text>
              </Pressable>
            ))}
          </View>
        </View>

        {/* Product details — category-specific */}
        {productCategory && (
          <CollapsibleSection
            title={catInfo ? `${catInfo.emoji}  ${catInfo.label}` : 'Product'}
            defaultOpen={true}
            summary={productSummary(productCategory, strainName, brand, productFlavor)}
            required>
            {renderProductFields()}
          </CollapsibleSection>
        )}

        {/* Where from? */}
        <CollapsibleSection title="Where from?"
          summary={whereFromSummary(sourceType, dispensaries, dispensaryId)}>
          <ChipRow options={SOURCE_TYPES} selected={sourceType} onSelect={setSourceType} />
          {dispensaries.length > 0 && (() => {
            const filtered = dispensaries.filter(d =>
              !sourceType || !d.venue_type || d.venue_type === sourceType
            );
            if (filtered.length === 0) return null;
            return (
              <>
                <Text style={[s.subLabel, { marginTop:14 }]}>Dispensary</Text>
                <Pressable onPress={() => setShowDispensaryPicker(true)} style={s.pickerBtn}>
                  <Text style={[s.pickerText, !selectedDispensary && { color:C.light }]}>
                    {selectedDispensary ? selectedDispensary.name : 'Select dispensary…'}
                  </Text>
                  <Text style={s.pickerChevron}>›</Text>
                </Pressable>
                {selectedDispensary && (
                  <Pressable onPress={() => setDispensaryId(null)}>
                    <Text style={{ fontSize:12, color:C.danger, marginTop:4 }}>Clear selection</Text>
                  </Pressable>
                )}
              </>
            );
          })()}
        </CollapsibleSection>

        {/* When and where? */}
        <CollapsibleSection title="When and where?" summary={whenSummary(timeOfDay, setting)}>
          <Text style={s.subLabel}>Time of day</Text>
          <ChipRow options={TIMES} selected={timeOfDay} onSelect={v => setTimeOfDay(v ?? getCurrentTimeOfDay())} />
          <Text style={[s.subLabel, { marginTop:14 }]}>Setting</Text>
          <ChipRow options={SETTINGS} selected={setting} onSelect={setSetting} />
        </CollapsibleSection>

        {/* Overall — 5 stars */}
        <CollapsibleSection title="Overall?" summary={overallSummary(overallRating)}>
          <View style={s.starsRow}>
            {[1,2,3,4,5].map(n => (
              <Pressable key={n} hitSlop={10}
                onPress={() => setOverallRating(overallRating === n ? null : n)}>
                <Text style={[s.star, { color: overallRating && n <= overallRating ? C.amber : C.border }]}>
                  {overallRating && n <= overallRating ? '★' : '☆'}
                </Text>
              </Pressable>
            ))}
          </View>
          {overallRating && (
            <Text style={[s.ratingWord, { color:ratingColor(overallRating) }]}>
              {ratingLabel(overallRating)} session
            </Text>
          )}
        </CollapsibleSection>

        {/* Effects */}
        <CollapsibleSection title="Effects felt"
          summary={effectsSummary(effects) ?? triStateSummary(couchLock, hunger)}>
          <Text style={s.effectHint}>Tap a dot to rate. Tap again to clear.</Text>
          {EFFECTS.map(e => (
            <EffectSlider key={e.key} label={e.label} icon={e.icon}
              value={effects[e.key]??null}
              onChange={val => setEffects(prev => ({ ...prev, [e.key]: val }))} />
          ))}
          <View style={s.triDivider} />
          <Text style={[s.subLabel, { marginBottom:10 }]}>Ambiguous effects</Text>
          <TriStateToggle label="Couch-lock" icon="◐" value={couchLock} onChange={setCouchLock} />
          <TriStateToggle label="Hunger / munchies" icon="◑" value={hunger} onChange={setHunger} />
        </CollapsibleSection>

        {/* Side effects */}
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

        {/* Timing */}
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

        {/* Notes */}
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

      {/* Dispensary picker modal */}
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

// ── Styles ────────────────────────────────────────────────────────────────────

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
  saveText: { color:'#FFF', fontSize:14, fontWeight:'500' },
  scroll: { flex:1 },
  scrollContent: { paddingTop:4, paddingBottom:8 },

  // Category picker
  categorySection: { paddingHorizontal:20, paddingTop:16, paddingBottom:4 },
  categorySectionLabel: { fontSize:12, color:C.muted, letterSpacing:0.8,
    textTransform:'uppercase', marginBottom:10 },
  categoryGrid: { flexDirection:'row', flexWrap:'wrap', gap:8 },
  categoryChip: { flexDirection:'row', alignItems:'center', gap:6,
    paddingHorizontal:12, paddingVertical:8, borderRadius:20, borderWidth:0.5,
    borderColor:C.border, backgroundColor:C.surface },
  categoryChipActive: { backgroundColor:C.accent, borderColor:C.accent },
  categoryEmoji: { fontSize:15 },
  categoryChipLabel: { fontSize:13, color:C.muted, fontWeight:'500' },
  categoryChipLabelActive: { color:'#FFF' },

  // Form fields
  subLabel: { fontSize:12, color:C.muted, letterSpacing:0.8, textTransform:'uppercase', marginBottom:8 },
  mainInput: { fontFamily:'Georgia', fontSize:22, color:C.text, borderBottomWidth:1,
    borderBottomColor:C.border, paddingBottom:10, letterSpacing:0.3 },
  input: { fontSize:15, color:C.text, backgroundColor:C.surface, borderRadius:8,
    paddingHorizontal:14, paddingVertical:11, borderWidth:0.5, borderColor:C.border },
  notesInput: { fontSize:15, color:C.text, backgroundColor:C.surface, borderRadius:8,
    paddingHorizontal:14, paddingVertical:14, borderWidth:0.5, borderColor:C.border,
    minHeight:110, lineHeight:22 },

  // mg fields
  mgRow: { flexDirection:'row', gap:12 },
  mgField: { flex:1 },
  mgInput: { fontSize:18, fontFamily:'Georgia', color:C.text, backgroundColor:C.surface,
    borderRadius:8, paddingHorizontal:14, paddingVertical:11, borderWidth:0.5,
    borderColor:C.border, textAlign:'center' },

  // Chips
  chipRow: { flexDirection:'row', flexWrap:'wrap', gap:8 },
  chip: { paddingHorizontal:14, paddingVertical:8, borderRadius:20, borderWidth:0.5,
    borderColor:C.border, backgroundColor:C.surface },
  chipActive: { backgroundColor:C.accent, borderColor:C.accent },
  chipText: { fontSize:13, color:C.muted },
  chipTextActive: { color:'#FFF', fontWeight:'500' },

  // Star rating
  starsRow: { flexDirection:'row', gap:8, alignItems:'center', paddingVertical:4 },
  star: { fontSize:38 },
  ratingWord: { marginTop:8, fontSize:13, fontFamily:'Georgia', letterSpacing:0.2 },

  // Effect sliders
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

  // Side effects
  sideRow: { flexDirection:'row', flexWrap:'wrap', gap:8 },
  sideChip: { flexDirection:'row', alignItems:'center', gap:6, paddingHorizontal:12,
    paddingVertical:8, borderRadius:6, borderWidth:0.5, borderColor:C.border, backgroundColor:C.surface },
  sideChipActive: { backgroundColor:C.dangerLt, borderColor:C.danger },
  sideCheck: { width:16, height:16, borderRadius:4, borderWidth:0.5, borderColor:C.border,
    alignItems:'center', justifyContent:'center', backgroundColor:C.bg },
  sideCheckActive: { backgroundColor:C.danger, borderColor:C.danger },
  sideCheckMark: { color:'#FFF', fontSize:10, fontWeight:'700' },
  sideChipText: { fontSize:13, color:C.muted },
  sideChipTextActive: { color:C.danger },

  // Timing
  timingRow: { flexDirection:'row', gap:16 },
  timingField: { flex:1 },
  timingInputRow: { flexDirection:'row', alignItems:'center', gap:8 },
  timingInput: { flex:1, fontSize:20, fontFamily:'Georgia', color:C.text,
    backgroundColor:C.surface, borderRadius:8, paddingHorizontal:14, paddingVertical:11,
    borderWidth:0.5, borderColor:C.border, textAlign:'center' },
  timingUnit: { fontSize:13, color:C.muted },

  // Dispensary picker
  pickerBtn: { flexDirection:'row', alignItems:'center', justifyContent:'space-between',
    backgroundColor:C.surface, borderRadius:8, borderWidth:0.5, borderColor:C.border,
    paddingHorizontal:14, paddingVertical:12 },
  pickerText: { fontSize:15, color:C.text, flex:1 },
  pickerChevron: { fontSize:20, color:C.muted },

  // Delete
  deleteBtn: { padding:14, borderRadius:8, borderWidth:0.5, borderColor:C.danger, alignItems:'center' },
  deleteBtnText: { fontSize:15, color:C.danger, fontWeight:'500' },

  // Modal
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
