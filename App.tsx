import React, { useEffect, useState, useRef, useCallback } from "react";
import { View, Text, ActivityIndicator, StyleSheet, Linking } from "react-native";
import { NavigationContainer, useNavigationContainerRef } from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { SafeAreaProvider, useSafeAreaInsets } from "react-native-safe-area-context";
import { initDb } from "./src/db/database";
import { C } from "./src/theme/colors";
import { StashPassProvider } from "./src/context/StashPassContext";
import { DiaryScreen }         from "./src/screens/DiaryScreen";
import { LogSessionScreen }    from "./src/screens/LogSessionScreen";
import { ExploreScreen }       from "./src/screens/ExploreScreen";
import { CategoryScreen }      from "./src/screens/CategoryScreen";
import { DispensaryScreen }    from "./src/screens/DispensaryScreen";
import { RecommendScreen }     from "./src/screens/RecommendScreen";
import { ProfileScreen }       from "./src/screens/ProfileScreen";
import { SettingsScreen }      from "./src/screens/SettingsScreen";
import { CirclesScreen }       from "./src/screens/circles/CirclesScreen";
import { CircleDetailScreen }  from "./src/screens/circles/CircleDetailScreen";
import { CreateCircleScreen }  from "./src/screens/circles/CreateCircleScreen";
import { ShareToCircleScreen } from "./src/screens/circles/ShareToCircleScreen";
import { JoinCircleScreen }    from "./src/screens/circles/JoinCircleScreen";
import { parseInviteUrl }      from "./src/services/circles";

const Tab   = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

function DiaryStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="DiaryList"  component={DiaryScreen} />
      <Stack.Screen name="LogSession" component={LogSessionScreen}
        options={{ presentation: "modal", animation: "slide_from_bottom" }} />
    </Stack.Navigator>
  );
}

function ExploreStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="ExploreHome" component={ExploreScreen} />
      <Stack.Screen name="Category"    component={CategoryScreen} />
    </Stack.Navigator>
  );
}

function SettingsStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="SettingsList" component={SettingsScreen} />
      <Stack.Screen name="Dispensaries" component={DispensaryScreen} />
    </Stack.Navigator>
  );
}

function CirclesStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="CirclesList"  component={CirclesScreen} />
      <Stack.Screen name="CircleDetail" component={CircleDetailScreen} />
      <Stack.Screen name="JoinCircle"   component={JoinCircleScreen} />
      <Stack.Screen name="CreateCircle" component={CreateCircleScreen}
        options={{ presentation: "modal", animation: "slide_from_bottom" }} />
      <Stack.Screen name="ShareToCircle" component={ShareToCircleScreen}
        options={{ presentation: "modal", animation: "slide_from_bottom" }} />
    </Stack.Navigator>
  );
}

function MainTabs() {
  const insets = useSafeAreaInsets();
  return (
    <Tab.Navigator screenOptions={{
      headerShown: false,
      tabBarStyle: { backgroundColor: C.bg, borderTopColor: C.border,
        borderTopWidth: 0.5, height: 60 + insets.bottom },
      tabBarLabelStyle: { fontSize: 11, letterSpacing: 0.3 },
      tabBarActiveTintColor:   C.accent,
      tabBarInactiveTintColor: C.light,
    }}>
      <Tab.Screen name="Diary"    component={DiaryStack}      options={{ tabBarLabel: "Journal" }} />
      <Tab.Screen name="Explore"  component={ExploreStack}    options={{ tabBarLabel: "Explore" }} />
      <Tab.Screen name="Find"     component={RecommendScreen}  options={{ tabBarLabel: "Find" }} />
      <Tab.Screen name="Circles"  component={CirclesStack}    options={{ tabBarLabel: "Circles", tabBarActiveTintColor: C.circles }} />
      <Tab.Screen name="Profile"  component={ProfileScreen}    options={{ tabBarLabel: "Profile" }} />
      <Tab.Screen name="Settings" component={SettingsStack}    options={{ tabBarLabel: "Settings" }} />
    </Tab.Navigator>
  );
}

export default function App() {
  const [ready, setReady]   = useState(false);
  const [error, setError]   = useState<string | null>(null);
  const navRef              = useNavigationContainerRef();
  const pendingUrl          = useRef<string | null>(null);

  const handleDeepLink = useCallback((url: string) => {
    const parsed = parseInviteUrl(url);
    if (!parsed) return;
    if (navRef.isReady()) {
      navRef.navigate('Circles' as never, {
        screen: 'JoinCircle',
        params: { circleId: parsed.circleId, token: parsed.token },
      } as never);
    } else {
      pendingUrl.current = url;
    }
  }, [navRef]);

  useEffect(() => {
    initDb()
      .then(() => setReady(true))
      .catch(err => setError(err.message ?? 'DB init failed'));

    Linking.getInitialURL().then(url => { if (url) handleDeepLink(url); });
    const sub = Linking.addEventListener('url', ({ url }) => handleDeepLink(url));
    return () => sub.remove();
  }, [handleDeepLink]);

  return (
    <SafeAreaProvider>
      <StashPassProvider>
        {error ? (
          <View style={[st.center, { backgroundColor: C.bg }]}>
            <Text style={{ fontFamily: "Georgia", fontSize: 18, color: C.danger }}>Failed to start</Text>
            <Text style={{ fontSize: 13, color: C.muted, marginTop: 8 }}>{error}</Text>
          </View>
        ) : !ready ? (
          <View style={[st.center, { backgroundColor: C.bg }]}>
            <ActivityIndicator color={C.accent} size="large" />
            <Text style={{ fontSize: 14, color: C.muted, marginTop: 12 }}>Starting up...</Text>
          </View>
        ) : (
          <NavigationContainer
            ref={navRef}
            onReady={() => {
              if (pendingUrl.current) {
                handleDeepLink(pendingUrl.current);
                pendingUrl.current = null;
              }
            }}
          >
            <MainTabs />
          </NavigationContainer>
        )}
      </StashPassProvider>
    </SafeAreaProvider>
  );
}

const st = StyleSheet.create({
  center: { flex: 1, alignItems: "center", justifyContent: "center" },
});
