import React, { useEffect, useState } from "react";
import { View, Text, ActivityIndicator, StyleSheet } from "react-native";
import { NavigationContainer } from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { SafeAreaProvider, useSafeAreaInsets } from "react-native-safe-area-context";
import { initDb } from "./src/db/database";
import { C } from "./src/theme/colors";
import { DiaryScreen }     from "./src/screens/DiaryScreen";
import { LogSessionScreen } from "./src/screens/LogSessionScreen";
import { ExploreScreen }   from "./src/screens/ExploreScreen";
import { CategoryScreen }  from "./src/screens/CategoryScreen";
import { DispensaryScreen } from "./src/screens/DispensaryScreen";
import { RecommendScreen }  from "./src/screens/RecommendScreen";
import { ProfileScreen }    from "./src/screens/ProfileScreen";
import { SettingsScreen }   from "./src/screens/SettingsScreen";

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
      <Tab.Screen name="Diary"    component={DiaryStack}     options={{ tabBarLabel: "Journal" }} />
      <Tab.Screen name="Explore"  component={ExploreStack}   options={{ tabBarLabel: "Explore" }} />
      <Tab.Screen name="Find"     component={RecommendScreen} options={{ tabBarLabel: "Find" }} />
      <Tab.Screen name="Profile"  component={ProfileScreen}   options={{ tabBarLabel: "Profile" }} />
      <Tab.Screen name="Settings" component={SettingsStack}   options={{ tabBarLabel: "Settings" }} />
    </Tab.Navigator>
  );
}

export default function App() {
  const [ready, setReady] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    initDb()
      .then(() => setReady(true))
      .catch(err => setError(err.message));
  }, []);

  return (
    <SafeAreaProvider>
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
        <NavigationContainer>
          <MainTabs />
        </NavigationContainer>
      )}
    </SafeAreaProvider>
  );
}

const st = StyleSheet.create({
  center: { flex: 1, alignItems: "center", justifyContent: "center" },
});
