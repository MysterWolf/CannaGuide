import React from 'react';
import { View, Text, Pressable, StyleSheet, StatusBar } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { C } from '../theme/colors';

export function CategoryScreen() {
  const nav    = useNavigation<any>();
  const route  = useRoute<any>();
  const { category, emoji } = route.params ?? {};

  return (
    <View style={st.root}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />

      <View style={st.header}>
        <Pressable onPress={() => nav.goBack()} style={st.backBtn} hitSlop={12}>
          <Text style={st.backArrow}>‹</Text>
        </Pressable>
        <Text style={st.title}>{emoji}  {category}</Text>
      </View>

      <View style={st.placeholder}>
        <Text style={st.placeholderEmoji}>{emoji}</Text>
        <Text style={st.placeholderText}>{category}</Text>
        <Text style={st.placeholderSub}>Content coming soon</Text>
      </View>
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
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: C.surface,
    borderWidth: 0.5,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: {
    fontSize: 22,
    color: C.text,
    lineHeight: 26,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    color: C.text,
    fontFamily: 'Georgia',
  },
  placeholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  placeholderEmoji: {
    fontSize: 52,
    marginBottom: 4,
  },
  placeholderText: {
    fontSize: 20,
    fontWeight: '600',
    color: C.text,
  },
  placeholderSub: {
    fontSize: 14,
    color: C.muted,
  },
});
