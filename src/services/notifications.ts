import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: false,
    shouldSetBadge:  false,
  }),
});

export async function requestNotificationPermission(): Promise<boolean> {
  if (Platform.OS !== 'android') return false;
  const { status } = await Notifications.requestPermissionsAsync();
  return status === 'granted';
}

export async function notifyJoinRequest(circleName: string, requesterName: string): Promise<void> {
  try {
    const { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') {
      await Notifications.requestPermissionsAsync();
    }
    await Notifications.scheduleNotificationAsync({
      content: {
        title: `New request for ${circleName}`,
        body:  `${requesterName} wants to join your Circle.`,
      },
      trigger: null,
    });
  } catch {
    // Notification permission denied — fail silently; badge in CirclesScreen is the fallback
  }
}
