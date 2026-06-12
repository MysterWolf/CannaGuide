import React, { useState, useEffect } from 'react';
import {
  View, Text, Pressable, StyleSheet, TextInput,
  ScrollView, StatusBar, KeyboardAvoidingView, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { C } from '../../theme/colors';
import { createCircle, createMember, getProfile, Member } from '../../services/circles';
import type { CirclesStackParamList } from './CirclesNavigator';

type Nav = NativeStackNavigationProp<CirclesStackParamList, 'CreateCircle'>;

const EMOJI_OPTIONS = ['🌿', '🔥', '💨', '⭐', '🌙', '🎯'];
const AVATAR_OPTIONS = ['🌿', '🔥', '💨', '⭐', '🌙', '🎯'];

export function CreateCircleScreen() {
  const nav = useNavigation<Nav>();

  const [name,        setName]        = useState('');
  const [emoji,       setEmoji]       = useState('🌿');
  const [memberInput, setMemberInput] = useState('');
  const [members,     setMembers]     = useState<Member[]>([]);
  const [profile,     setProfile]     = useState<Member | null>(null);
  const [saving,      setSaving]      = useState(false);

  useEffect(() => { getProfile().then(setProfile); }, []);

  const addMember = () => {
    const trimmed = memberInput.trim();
    if (!trimmed) return;
    if (members.some(m => m.displayName.toLowerCase() === trimmed.toLowerCase())) {
      setMemberInput('');
      return;
    }
    const m: Member = {
      userId:      Math.random().toString(36).slice(2) + Date.now().toString(36),
      displayName: trimmed,
      avatar:      AVATAR_OPTIONS[Math.floor(Math.random() * AVATAR_OPTIONS.length)],
    };
    setMembers(prev => [...prev, m]);
    setMemberInput('');
  };

  const removeMember = (userId: string) => {
    setMembers(prev => prev.filter(m => m.userId !== userId));
  };

  const handleSave = async () => {
    if (!name.trim() || !profile || saving) return;
    setSaving(true);
    try {
      await createCircle(name.trim(), emoji, profile, members);
      nav.goBack();
    } finally {
      setSaving(false);
    }
  };

  return (
    <SafeAreaView style={s.root} edges={['top', 'bottom']}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>

        {/* Header */}
        <View style={s.header}>
          <Pressable onPress={() => nav.goBack()} hitSlop={8}>
            <Text style={s.cancel}>Cancel</Text>
          </Pressable>
          <Text style={s.title}>New Circle</Text>
          <Pressable
            onPress={handleSave}
            disabled={!name.trim() || saving}
            hitSlop={8}
          >
            <Text style={[s.saveText, (!name.trim() || saving) && s.saveDisabled]}>
              {saving ? 'Saving…' : 'Create'}
            </Text>
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
          {/* Name */}
          <Text style={s.label}>Circle name</Text>
          <TextInput
            style={s.input}
            placeholder="e.g. The Crew, Portland Heads"
            placeholderTextColor={C.light}
            value={name}
            onChangeText={setName}
            maxLength={40}
            autoFocus
          />

          {/* Emoji picker */}
          <Text style={s.label}>Circle icon</Text>
          <View style={s.emojiRow}>
            {EMOJI_OPTIONS.map(e => (
              <Pressable
                key={e}
                style={[s.emojiOption, emoji === e && s.emojiSelected]}
                onPress={() => setEmoji(e)}
              >
                <Text style={s.emojiText}>{e}</Text>
              </Pressable>
            ))}
          </View>

          {/* Member invite */}
          <Text style={s.label}>Add members</Text>
          <Text style={s.hint}>Type a display name to add them to this Circle.</Text>
          <View style={s.memberInputRow}>
            <TextInput
              style={[s.input, { flex: 1, marginBottom: 0 }]}
              placeholder="Display name"
              placeholderTextColor={C.light}
              value={memberInput}
              onChangeText={setMemberInput}
              onSubmitEditing={addMember}
              returnKeyType="done"
              blurOnSubmit={false}
            />
            <Pressable
              style={[s.addMemberBtn, !memberInput.trim() && s.addMemberBtnDisabled]}
              onPress={addMember}
              disabled={!memberInput.trim()}
            >
              <Text style={s.addMemberBtnText}>Add</Text>
            </Pressable>
          </View>

          {/* Member pills */}
          {members.length > 0 && (
            <View style={s.pillsContainer}>
              {members.map(m => (
                <Pressable key={m.userId} style={s.pill} onPress={() => removeMember(m.userId)}>
                  <Text style={s.pillAvatar}>{m.avatar}</Text>
                  <Text style={s.pillName}>{m.displayName}</Text>
                  <Text style={s.pillRemove}>✕</Text>
                </Pressable>
              ))}
            </View>
          )}

          <Text style={s.footNote}>
            {profile?.displayName ? `You (${profile.displayName}) will be added automatically.` : ''}
          </Text>
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
  saveText:    { fontSize: 15, fontWeight: '700', color: C.circles },
  saveDisabled:{ opacity: 0.4 },

  scroll: { padding: 20, paddingBottom: 40 },

  label:  { fontSize: 11, fontWeight: '600', color: C.muted, letterSpacing: 0.8, marginBottom: 8, textTransform: 'uppercase' },
  hint:   { fontSize: 12, color: C.muted, marginTop: -4, marginBottom: 10 },
  input:  { backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, borderRadius: 10, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15, color: C.text, marginBottom: 24 },

  emojiRow:     { flexDirection: 'row', gap: 12, marginBottom: 28 },
  emojiOption:  { width: 50, height: 50, borderRadius: 25, backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, alignItems: 'center', justifyContent: 'center' },
  emojiSelected:{ borderColor: C.circles, borderWidth: 2, backgroundColor: C.circlesLt },
  emojiText:    { fontSize: 26 },

  memberInputRow:     { flexDirection: 'row', gap: 10, marginBottom: 16 },
  addMemberBtn:       { backgroundColor: C.circles, borderRadius: 10, paddingHorizontal: 16, justifyContent: 'center' },
  addMemberBtnDisabled:{ opacity: 0.4 },
  addMemberBtnText:   { color: C.white, fontWeight: '700', fontSize: 14 },

  pillsContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 20 },
  pill:      { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: C.circlesLt, borderWidth: 1, borderColor: C.circles + '60', borderRadius: 20, paddingVertical: 6, paddingHorizontal: 12 },
  pillAvatar:{ fontSize: 14 },
  pillName:  { fontSize: 13, color: C.text, fontWeight: '500' },
  pillRemove:{ fontSize: 11, color: C.muted, marginLeft: 2 },

  footNote: { fontSize: 12, color: C.light, marginTop: 8 },
});
