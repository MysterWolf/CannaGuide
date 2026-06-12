import React, { useState, useEffect } from 'react';
import {
  View, Text, Pressable, StyleSheet, TextInput,
  ScrollView, StatusBar, KeyboardAvoidingView, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp, RouteProp } from '@react-navigation/native-stack';
import { C } from '../../theme/colors';
import {
  getCircles, getProfile, addShare,
  Circle, Member, StorePayload, ProductPayload,
} from '../../services/circles';
import type { CirclesStackParamList } from './CirclesNavigator';

type Nav   = NativeStackNavigationProp<CirclesStackParamList, 'ShareToCircle'>;
type Route = RouteProp<CirclesStackParamList, 'ShareToCircle'>;

export function ShareToCircleScreen() {
  const nav   = useNavigation<Nav>();
  const route = useRoute<Route>();
  const { circleId: preCircleId, type: preType, payload: prePayload } = route.params ?? {};

  const [circles,     setCircles]     = useState<Circle[]>([]);
  const [profile,     setProfile]     = useState<Member | null>(null);
  const [selectedId,  setSelectedId]  = useState<string>(preCircleId ?? '');
  const [shareType,   setShareType]   = useState<'store' | 'product'>(preType ?? 'store');
  const [itemName,    setItemName]    = useState<string>((prePayload as any)?.name ?? '');
  const [itemSub,     setItemSub]     = useState<string>(
    prePayload ? ((prePayload as StorePayload).address ?? (prePayload as ProductPayload).brand ?? '') : '',
  );
  const [note,        setNote]        = useState('');
  const [saving,      setSaving]      = useState(false);

  useEffect(() => {
    Promise.all([getCircles(), getProfile()]).then(([c, p]) => {
      setCircles(c);
      setProfile(p);
      if (!preCircleId && c.length === 1) setSelectedId(c[0].id);
    });
  }, []);

  const hasPreloaded = !!prePayload;

  const handleShare = async () => {
    if (!selectedId || !itemName.trim() || !profile || saving) return;
    setSaving(true);
    try {
      const payload: StorePayload | ProductPayload = shareType === 'store'
        ? { id: Math.random().toString(36).slice(2), name: itemName.trim(), address: itemSub.trim() || undefined }
        : { id: Math.random().toString(36).slice(2), name: itemName.trim(), brand: itemSub.trim() || undefined };

      await addShare({
        circleId:  selectedId,
        sharerId:  profile.userId,
        type:      shareType,
        payload,
        note:      note.trim(),
        timestamp: Date.now(),
      });
      nav.goBack();
    } finally {
      setSaving(false);
    }
  };

  const canShare = !!selectedId && !!itemName.trim() && !!profile && !saving;

  return (
    <SafeAreaView style={s.root} edges={['top', 'bottom']}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>

        {/* Header */}
        <View style={s.header}>
          <Pressable onPress={() => nav.goBack()} hitSlop={8}>
            <Text style={s.cancel}>Cancel</Text>
          </Pressable>
          <Text style={s.title}>Share to Circle</Text>
          <Pressable onPress={handleShare} disabled={!canShare} hitSlop={8}>
            <Text style={[s.shareText, !canShare && s.shareDisabled]}>
              {saving ? 'Sharing…' : 'Share'}
            </Text>
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">

          {/* Type selector (only shown if not pre-loaded) */}
          {!hasPreloaded && (
            <>
              <Text style={s.label}>What are you sharing?</Text>
              <View style={s.typeRow}>
                {(['store', 'product'] as const).map(t => (
                  <Pressable
                    key={t}
                    style={[s.typeBtn, shareType === t && s.typeBtnActive]}
                    onPress={() => setShareType(t)}
                  >
                    <Text style={[s.typeBtnText, shareType === t && s.typeBtnTextActive]}>
                      {t === 'store' ? '🏪 Discovery' : '🌿 Product'}
                    </Text>
                  </Pressable>
                ))}
              </View>
            </>
          )}

          {/* What you're sharing */}
          <Text style={s.label}>{shareType === 'store' ? 'Store' : 'Product'} name</Text>
          {hasPreloaded ? (
            <View style={s.preloadCard}>
              <Text style={s.preloadName}>{itemName}</Text>
              {itemSub ? <Text style={s.preloadSub}>{itemSub}</Text> : null}
            </View>
          ) : (
            <>
              <TextInput
                style={s.input}
                placeholder={shareType === 'store' ? 'e.g. Nectar Portland' : 'e.g. Wedding Cake'}
                placeholderTextColor={C.light}
                value={itemName}
                onChangeText={setItemName}
                maxLength={60}
              />
              <TextInput
                style={[s.input, { marginTop: -14 }]}
                placeholder={shareType === 'store' ? 'Address (optional)' : 'Brand (optional)'}
                placeholderTextColor={C.light}
                value={itemSub}
                onChangeText={setItemSub}
                maxLength={60}
              />
            </>
          )}

          {/* Note */}
          <Text style={s.label}>Your note</Text>
          <TextInput
            style={[s.input, s.noteInput]}
            placeholder="Why do you love this? What should they know?"
            placeholderTextColor={C.light}
            value={note}
            onChangeText={setNote}
            multiline
            maxLength={280}
          />

          {/* Circle selector */}
          {circles.length > 1 && (
            <>
              <Text style={s.label}>Share to</Text>
              {circles.map(c => (
                <Pressable
                  key={c.id}
                  style={[s.circleOption, selectedId === c.id && s.circleOptionActive]}
                  onPress={() => setSelectedId(c.id)}
                >
                  <Text style={s.circleEmoji}>{c.emoji}</Text>
                  <Text style={[s.circleName, selectedId === c.id && { color: C.circles }]}>{c.name}</Text>
                  {selectedId === c.id && <Text style={s.checkmark}>✓</Text>}
                </Pressable>
              ))}
            </>
          )}

          {circles.length === 0 && (
            <View style={s.noCircles}>
              <Text style={s.noCirclesText}>You're not in any Circles yet. Create one first.</Text>
            </View>
          )}

          {!profile?.displayName && (
            <Text style={s.warn}>⚠️ Set your display name in Circles before sharing.</Text>
          )}
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  root:   { flex: 1, backgroundColor: C.bg },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: C.border },
  title:  { fontSize: 17, fontWeight: '700', color: C.text },
  cancel: { fontSize: 15, color: C.muted },
  shareText:    { fontSize: 15, fontWeight: '700', color: C.circles },
  shareDisabled:{ opacity: 0.4 },

  scroll: { padding: 20, paddingBottom: 40 },
  label:  { fontSize: 11, fontWeight: '600', color: C.muted, letterSpacing: 0.8, marginBottom: 8, textTransform: 'uppercase' },
  input:  { backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, borderRadius: 10, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15, color: C.text, marginBottom: 20 },
  noteInput: { minHeight: 90, textAlignVertical: 'top' },

  typeRow:          { flexDirection: 'row', gap: 10, marginBottom: 24 },
  typeBtn:          { flex: 1, borderRadius: 10, borderWidth: 1, borderColor: C.border, backgroundColor: C.surface, paddingVertical: 12, alignItems: 'center' },
  typeBtnActive:    { borderColor: C.circles, backgroundColor: C.circlesLt },
  typeBtnText:      { fontSize: 14, color: C.muted, fontWeight: '600' },
  typeBtnTextActive:{ color: C.circles },

  preloadCard: { backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, borderRadius: 10, padding: 14, marginBottom: 20 },
  preloadName: { fontSize: 15, fontWeight: '600', color: C.text },
  preloadSub:  { fontSize: 12, color: C.muted, marginTop: 4 },

  circleOption:       { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, borderRadius: 10, padding: 14, marginBottom: 10 },
  circleOptionActive: { borderColor: C.circles, backgroundColor: C.circlesLt },
  circleEmoji:        { fontSize: 22 },
  circleName:         { flex: 1, fontSize: 15, fontWeight: '600', color: C.text },
  checkmark:          { fontSize: 16, color: C.circles, fontWeight: '700' },

  noCircles:     { backgroundColor: C.surface, borderRadius: 10, padding: 16, alignItems: 'center' },
  noCirclesText: { fontSize: 14, color: C.muted, textAlign: 'center', lineHeight: 20 },

  warn: { fontSize: 13, color: C.amber, marginTop: 12 },
});
