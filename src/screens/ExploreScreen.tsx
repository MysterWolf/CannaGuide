import React from 'react';
import { View, Text, ScrollView, Pressable, StyleSheet, StatusBar } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { C } from '../theme/colors';

const CATEGORIES = [
  { id: 'flower',     label: 'Flower',        emoji: '🌿', color: C.sage,   colorLt: C.sageLt },
  { id: 'edibles',    label: 'Edibles',        emoji: '🍬', color: C.amber,  colorLt: C.amberLt },
  { id: 'beverages',  label: 'THC Beverages',  emoji: '🥤', color: C.sage,   colorLt: C.sageLt },
  { id: 'vapes',      label: 'Vapes',          emoji: '💨', color: C.purple, colorLt: C.purpleLt },
  { id: 'tinctures',  label: 'Tinctures',      emoji: '🧪', color: C.blue,   colorLt: C.blueLt },
  { id: 'topicals',   label: 'Topicals',       emoji: '🫧', color: C.amber,  colorLt: C.amberLt },
];

export function ExploreScreen() {
  const nav = useNavigation<any>();

  return (
    <View style={st.root}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />

      <View style={st.header}>
        <Text style={st.title}>Explore</Text>
        <Text style={st.subtitle}>Browse by category</Text>
      </View>

      <ScrollView contentContainerStyle={st.grid} showsVerticalScrollIndicator={false}>
        {CATEGORIES.map(cat => (
          <Pressable
            key={cat.id}
            style={({ pressed }) => [st.tile, pressed && st.tilePressed]}
            onPress={() => nav.navigate('Category', { category: cat.label, emoji: cat.emoji })}
          >
            <View style={[st.iconWrap, { backgroundColor: cat.colorLt }]}>
              <Text style={st.emoji}>{cat.emoji}</Text>
            </View>
            <Text style={st.tileLabel}>{cat.label}</Text>
            <Text style={[st.arrow, { color: cat.color }]}>›</Text>
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}

const st = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: C.bg,
  },
  header: {
    paddingTop: 56,
    paddingHorizontal: 20,
    paddingBottom: 16,
    borderBottomWidth: 0.5,
    borderBottomColor: C.border,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: C.text,
    fontFamily: 'Georgia',
    marginBottom: 2,
  },
  subtitle: {
    fontSize: 13,
    color: C.muted,
  },
  grid: {
    padding: 16,
    gap: 10,
  },
  tile: {
    backgroundColor: C.surface,
    borderRadius: 14,
    borderWidth: 0.5,
    borderColor: C.border,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  tilePressed: {
    opacity: 0.7,
  },
  iconWrap: {
    width: 48,
    height: 48,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emoji: {
    fontSize: 24,
  },
  tileLabel: {
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
    color: C.text,
  },
  arrow: {
    fontSize: 22,
    fontWeight: '300',
  },
});
