import React, { useState, useRef } from 'react';
import {
  View, Text, Pressable, Animated, StyleSheet,
} from 'react-native';
import { C } from '../theme/colors';

interface Props {
  title:        string;
  defaultOpen?: boolean;
  summary?:     string;      // shown when collapsed — e.g. "Flower · Evening"
  required?:    boolean;     // shows a subtle dot when section has no data
  children:     React.ReactNode;
}

export function CollapsibleSection({
  title,
  defaultOpen = false,
  summary,
  required = false,
  children,
}: Props) {
  const [open, setOpen] = useState(defaultOpen);
  const rotation = useRef(new Animated.Value(defaultOpen ? 1 : 0)).current;

  const toggle = () => {
    const toValue = open ? 0 : 1;
    Animated.timing(rotation, {
      toValue, duration: 200, useNativeDriver: true,
    }).start();
    setOpen(o => !o);
  };

  const rotate = rotation.interpolate({
    inputRange: [0, 1], outputRange: ['0deg', '90deg'],
  });

  const hasSummary = !!summary;

  return (
    <View style={s.wrapper}>
      <Pressable onPress={toggle} style={s.header}>
        <View style={s.headerLeft}>
          {/* Required dot — shows when section is empty and required */}
          {required && !hasSummary && (
            <View style={s.requiredDot} />
          )}
          {/* Filled dot — shows when section has data */}
          {hasSummary && (
            <View style={s.filledDot} />
          )}
          <Text style={s.title}>{title}</Text>
        </View>
        <View style={s.headerRight}>
          {!open && hasSummary && (
            <Text style={s.summary} numberOfLines={1}>{summary}</Text>
          )}
          <Animated.Text style={[s.chevron, { transform: [{ rotate }] }]}>
            ›
          </Animated.Text>
        </View>
      </Pressable>

      {open && (
        <View style={s.content}>
          {children}
        </View>
      )}

      <View style={s.divider} />
    </View>
  );
}

const s = StyleSheet.create({
  wrapper: {
    backgroundColor: C.bg,
  },
  header: {
    flexDirection:  'row',
    alignItems:     'center',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    paddingVertical:   16,
    gap: 12,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems:    'center',
    gap:           8,
    flex:          1,
  },
  requiredDot: {
    width: 6, height: 6, borderRadius: 3,
    backgroundColor: C.border,
    flexShrink: 0,
  },
  filledDot: {
    width: 6, height: 6, borderRadius: 3,
    backgroundColor: C.sage,
    flexShrink: 0,
  },
  title: {
    fontFamily:    'Georgia',
    fontSize:      17,
    color:         C.text,
    letterSpacing: 0.2,
    flex:          1,
  },
  headerRight: {
    flexDirection: 'row',
    alignItems:    'center',
    gap:           6,
    flexShrink:    0,
    maxWidth:      '50%',
  },
  summary: {
    fontSize:  12,
    color:     C.muted,
    flexShrink: 1,
  },
  chevron: {
    fontSize: 20,
    color:    C.muted,
    width:    16,
  },
  content: {
    paddingHorizontal: 24,
    paddingBottom:     20,
    paddingTop:        4,
  },
  divider: {
    height:          0.5,
    backgroundColor: C.border,
    marginHorizontal: 24,
  },
});
