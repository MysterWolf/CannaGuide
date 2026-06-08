import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, TextInput, Pressable, StyleSheet,
  Platform, StatusBar, Alert, Switch, Linking,
  NativeModules, PermissionsAndroid, ActivityIndicator,
} from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import * as DocumentPicker from 'expo-document-picker';
import { dbGetFirst, dbRun, dbAll, isoNow, closeDb, reopenDb } from '../db/database';
import { C } from '../theme/colors';
import { useStashPass } from '../context/StashPassContext';

const APP_VERSION  = '1.0.0';
const FEEDBACK_URL = 'mailto:hello@cannaguide.app?subject=CannaGuide Feedback';

// ============================================================
// SUB-COMPONENTS
// ============================================================

function SectionHeader({ children }: { children: string }) {
  return <Text style={s.sectionHeader}>{children}</Text>;
}

function SettingRow({
  label, value, onPress, destructive, sub, rightElement,
}: {
  label: string; value?: string; onPress?: () => void;
  destructive?: boolean; sub?: string; rightElement?: React.ReactNode;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress && !rightElement}
      style={({ pressed }) => [s.row, pressed && onPress && s.rowPressed]}>
      <View style={s.rowLeft}>
        <Text style={[s.rowLabel, destructive && { color: C.danger }]}>{label}</Text>
        {sub && <Text style={s.rowSub}>{sub}</Text>}
      </View>
      {rightElement ?? (
        value !== undefined && (
          <Text style={[s.rowValue, destructive && { color: C.danger }]}>{value}</Text>
        )
      )}
    </Pressable>
  );
}

function TierBadge({ tier }: { tier: string }) {
  const config: Record<string, { label: string; bg: string; text: string }> = {
    free: { label: 'Free',  bg: C.surface,  text: C.muted },
    pro:  { label: 'Pro',   bg: C.purpleLt, text: C.purpleMid },
  };
  const c = config[tier] ?? config.free;
  return (
    <View style={[s.tierBadge, { backgroundColor: c.bg }]}>
      <Text style={[s.tierBadgeText, { color: c.text }]}>{c.label}</Text>
    </View>
  );
}

// ============================================================
// MAIN SCREEN
// ============================================================
export function SettingsScreen({ navigation }: { navigation: any }) {
  const [user,      setUser]      = useState<any>(null);
  const [threshold, setThreshold] = useState(5);
  const [loading,   setLoading]   = useState(true);

  // StashPass connect flow
  const { isConnected, requestOtp, verifyOtp, disconnect } = useStashPass();
  const [spContact,    setSpContact]    = useState('');
  const [spOtp,        setSpOtp]        = useState('');
  const [spStep,       setSpStep]       = useState<0 | 1>(0); // 0=idle/input, 1=awaiting OTP
  const [spSending,    setSpSending]    = useState(false);
  const [spVerifying,  setSpVerifying]  = useState(false);

  const handleSpRequest = useCallback(async () => {
    if (!spContact.trim()) { Alert.alert('Enter phone or email'); return; }
    setSpSending(true);
    try {
      await requestOtp(spContact.trim());
      setSpStep(1);
    } catch (err: any) {
      Alert.alert('Failed to send OTP', err.message);
    } finally {
      setSpSending(false);
    }
  }, [spContact, requestOtp]);

  const handleSpVerify = useCallback(async () => {
    if (!spOtp.trim()) { Alert.alert('Enter the code from your message'); return; }
    setSpVerifying(true);
    try {
      await verifyOtp(spContact.trim(), spOtp.trim());
      setSpContact(''); setSpOtp(''); setSpStep(0);
      Alert.alert('Connected', 'StashPass wallet linked.');
    } catch (err: any) {
      Alert.alert('Invalid code', err.message);
    } finally {
      setSpVerifying(false);
    }
  }, [spContact, spOtp, verifyOtp]);

  const handleSpDisconnect = useCallback(() => {
    Alert.alert(
      'Disconnect StashPass',
      'Your points balance will not be lost — you can reconnect anytime.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Disconnect', style: 'destructive', onPress: () => disconnect() },
      ]
    );
  }, [disconnect]);

  const loadData = useCallback(async () => {
    try {
      const u = await dbGetFirst<any>('SELECT * FROM users LIMIT 1');
      setUser(u);
      setThreshold(u?.profile_rebuild_threshold ?? 5);
    } catch (err) {
      console.error('[Settings] Load error:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);
  useEffect(() => {
    const unsub = navigation.addListener('focus', loadData);
    return unsub;
  }, [navigation, loadData]);

  const handleThresholdChange = useCallback(async (value: number) => {
    setThreshold(value);
    if (!user?.id) return;
    await dbRun(
      'UPDATE users SET profile_rebuild_threshold = ?, updated_at = ? WHERE id = ?',
      [value, isoNow(), user.id]
    );
  }, [user]);

  const handleWipe = useCallback(() => {
    Alert.alert(
      'Delete all data',
      'This permanently deletes your journal, strains, dispensaries and profile. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete everything',
          style: 'destructive',
          onPress: async () => {
            try {
              await dbRun('DELETE FROM sessions');
              await dbRun('DELETE FROM user_effect_profile');
              await dbRun('DELETE FROM recommendations');
              await dbRun('DELETE FROM ai_usage_log');
              await dbRun('DELETE FROM wishlist');
              await dbRun('DELETE FROM inventory');
              await dbRun('DELETE FROM dispensaries');
              await dbRun('DELETE FROM strains');
              if (user?.id) {
                await dbRun(
                  `UPDATE users SET tier='free', sub_expires_at=NULL,
                   sessions_since_last_profile=0, updated_at=? WHERE id=?`,
                  [isoNow(), user.id]
                );
              }
              Alert.alert('Done', 'All data has been deleted.');
              loadData();
            } catch (err: any) {
              Alert.alert('Error', err.message);
            }
          },
        },
      ]
    );
  }, [user, loadData]);

  const handleForceRebuild = useCallback(async () => {
    if (!user?.id) return;
    await dbRun(
      'UPDATE users SET sessions_since_last_profile = profile_rebuild_threshold WHERE id = ?',
      [user.id]
    );
    Alert.alert('Queued', 'Profile will rebuild next time you open the Recommend tab.');
  }, [user]);

  const handleExportDb = useCallback(async () => {
    try {
      const src = FileSystem.documentDirectory + 'SQLite/cannaguide.db';
      const info = await FileSystem.getInfoAsync(src);
      if (!info.exists) { Alert.alert('Error', 'Database file not found.'); return; }
      // Checkpoint WAL into main DB file so all data is flushed before copy
      await dbAll('PRAGMA wal_checkpoint(TRUNCATE)', []);
      await closeDb();
      try {
        // Android 9 and below requires WRITE_EXTERNAL_STORAGE at runtime
        if (Platform.OS === 'android' && (Platform.Version as number) < 29) {
          const granted = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
            {
              title: 'Storage Permission Required',
              message: 'CannaGuide needs storage access to save your backup to Downloads.',
              buttonPositive: 'Allow',
              buttonNegative: 'Cancel',
            }
          );
          if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
            Alert.alert('Permission denied', 'Storage permission is required to save backups to Downloads.');
            return;
          }
        }
        const dbPath = src.replace('file://', '');
        await NativeModules.DownloadModule.saveToDownloads(dbPath, 'cannaguide_backup.db');
        Alert.alert('Backup saved', 'cannaguide_backup.db saved to your Downloads folder.');
      } finally {
        await reopenDb();
      }
    } catch (err: any) {
      Alert.alert('Export failed', err.message);
    }
  }, []);

  const handleImportDb = useCallback(async () => {
    Alert.alert(
      'Restore from backup',
      'This will replace ALL current data with the selected backup file. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Choose file',
          onPress: async () => {
            try {
              const result = await DocumentPicker.getDocumentAsync({ type: '*/*', copyToCacheDirectory: true });
              if (result.canceled || !result.assets?.length) return;
              const { uri } = result.assets[0];
              // Verify SQLite magic bytes
              const header = await FileSystem.readAsStringAsync(uri, { encoding: FileSystem.EncodingType.Base64, length: 16 });
              const magic = atob(header).slice(0, 15);
              if (!magic.startsWith('SQLite format 3')) {
                Alert.alert('Invalid file', 'The selected file is not a SQLite database.');
                return;
              }
              const dst = FileSystem.documentDirectory + 'SQLite/cannaguide.db';
              await closeDb();
              await FileSystem.copyAsync({ from: uri, to: dst });
              await reopenDb();
              Alert.alert('Restored', 'Database restored. Restart the app to see your data.', [
                { text: 'OK', onPress: () => navigation.goBack() },
              ]);
            } catch (err: any) {
              await reopenDb().catch(() => {});
              Alert.alert('Import failed', err.message);
            }
          },
        },
      ]
    );
  }, [navigation]);

  const tier = user?.tier ?? 'free';
  const isPro = tier === 'pro';

  const THRESHOLDS = [3, 5, 10, 20];

  return (
    <View style={s.root}>
      <StatusBar barStyle="dark-content" backgroundColor={C.bg} />
      <View style={s.header}>
        <Text style={s.headerTitle}>Settings</Text>
      </View>

      <ScrollView style={s.scroll} contentContainerStyle={s.scrollContent}
        showsVerticalScrollIndicator={false}>

        {/* ---- ACCOUNT ---- */}
        <SectionHeader>Account</SectionHeader>
        <View style={s.group}>
          <SettingRow
            label="Plan"
            rightElement={<TierBadge tier={tier} />}
          />
          {user?.sub_expires_at && (
            <SettingRow
              label="Renews"
              value={new Date(user.sub_expires_at).toLocaleDateString('en-US', {
                month: 'short', day: 'numeric', year: 'numeric'
              })}
            />
          )}
          {!isPro ? (
            <SettingRow
              label="Upgrade to Pro"
              sub="Unlock AI recommendations for $6.99/mo"
              onPress={() => Alert.alert('Coming soon', 'In-app purchase coming before release.')}
              rightElement={
                <View style={s.upgradeArrow}>
                  <Text style={{ color: C.white, fontSize: 14 }}>→</Text>
                </View>
              }
            />
          ) : (
            <SettingRow
              label="Manage subscription"
              sub="Cancel or change in the App Store"
              onPress={() => Linking.openURL('https://apps.apple.com/account/subscriptions')}
              value="→"
            />
          )}
        </View>

        {/* ---- STASHPASS WALLET ---- */}
        <SectionHeader>StashPass Wallet</SectionHeader>
        <View style={s.group}>
          {isConnected ? (
            <SettingRow
              label="Wallet connected"
              sub="Earn and redeem points at participating dispensaries"
              onPress={handleSpDisconnect}
              rightElement={
                <View style={sp.connectedBadge}>
                  <Text style={sp.connectedBadgeText}>Connected</Text>
                </View>
              }
            />
          ) : (
            <View style={sp.connectBlock}>
              {spStep === 0 ? (
                <>
                  <Text style={sp.connectLabel}>Phone or email</Text>
                  <View style={sp.inputRow}>
                    <TextInput
                      style={sp.input}
                      placeholder="e.g. +1 555 000 0000"
                      placeholderTextColor={C.light}
                      value={spContact}
                      onChangeText={setSpContact}
                      autoCapitalize="none"
                      keyboardType="email-address"
                    />
                    <Pressable
                      onPress={handleSpRequest}
                      disabled={spSending}
                      style={[sp.sendBtn, spSending && { opacity: 0.5 }]}>
                      {spSending
                        ? <ActivityIndicator size="small" color={C.white} />
                        : <Text style={sp.sendBtnText}>Send code</Text>}
                    </Pressable>
                  </View>
                </>
              ) : (
                <>
                  <Text style={sp.connectLabel}>Enter the 6-digit code</Text>
                  <View style={sp.inputRow}>
                    <TextInput
                      style={sp.input}
                      placeholder="000000"
                      placeholderTextColor={C.light}
                      value={spOtp}
                      onChangeText={setSpOtp}
                      keyboardType="number-pad"
                      maxLength={6}
                    />
                    <Pressable
                      onPress={handleSpVerify}
                      disabled={spVerifying}
                      style={[sp.sendBtn, spVerifying && { opacity: 0.5 }]}>
                      {spVerifying
                        ? <ActivityIndicator size="small" color={C.white} />
                        : <Text style={sp.sendBtnText}>Verify</Text>}
                    </Pressable>
                  </View>
                  <Pressable onPress={() => { setSpStep(0); setSpOtp(''); }}>
                    <Text style={sp.backLink}>← Use a different address</Text>
                  </Pressable>
                </>
              )}
            </View>
          )}
        </View>

        {/* ---- DISPENSARIES ---- */}
        <SectionHeader>Dispensaries</SectionHeader>
        <View style={s.group}>
          <SettingRow
            label="Manage dispensaries"
            sub="Add, rate, and remove your saved dispensaries"
            onPress={() => navigation.navigate('Dispensaries')}
            value="→"
          />
        </View>

        {/* ---- PROFILE PREFERENCES ---- */}
        <SectionHeader>Profile preferences</SectionHeader>
        <View style={s.group}>
          <View style={[s.row, { flexDirection: 'column', alignItems: 'flex-start', gap: 10 }]}>
            <Text style={s.rowLabel}>Rebuild every</Text>
            <Text style={s.rowSub}>How many new sessions trigger an AI profile rebuild</Text>
            <View style={s.thresholdRow}>
              {THRESHOLDS.map(n => (
                <Pressable
                  key={n}
                  onPress={() => handleThresholdChange(n)}
                  disabled={!isPro}
                  style={[
                    s.thresholdChip,
                    threshold === n && s.thresholdChipActive,
                    !isPro && { opacity: 0.4 },
                  ]}>
                  <Text style={[
                    s.thresholdChipText,
                    threshold === n && s.thresholdChipTextActive,
                  ]}>
                    {n} sessions
                  </Text>
                </Pressable>
              ))}
            </View>
            {!isPro && (
              <Text style={s.lockedNote}>Requires Pro</Text>
            )}
          </View>
          <SettingRow
            label="Rebuild profile now"
            sub={isPro ? 'Force a rebuild using all current sessions' : 'Requires Pro'}
            onPress={isPro ? handleForceRebuild : undefined}
            value={isPro ? '→' : undefined}
          />
        </View>

        {/* ---- PRIVACY ---- */}
        <SectionHeader>Privacy & data</SectionHeader>
        <View style={s.group}>
          <View style={s.privacyNote}>
            <Text style={s.privacyTitle}>Your data stays on your phone</Text>
            <Text style={s.privacyBody}>
              CannaGuide stores everything locally. Your journal never leaves
              your device. AI calls send anonymised session summaries only.
            </Text>
          </View>
          <SettingRow
            label="Delete all data"
            sub="Permanently wipes your journal and profile"
            onPress={handleWipe}
            destructive
            value="→"
          />
        </View>

        {/* ---- BACKUP / RESTORE ---- */}
        <SectionHeader>Backup & restore</SectionHeader>
        <View style={s.group}>
          <SettingRow
            label="Export database"
            sub="Save a backup file to share or store"
            onPress={handleExportDb}
            value="↑"
          />
          <SettingRow
            label="Restore from backup"
            sub="Replace all data with a backup file"
            onPress={handleImportDb}
            destructive
            value="↓"
          />
        </View>

        {/* ---- APP ---- */}
        <SectionHeader>App</SectionHeader>
        <View style={s.group}>
          <SettingRow
            label="Send feedback"
            onPress={() => Linking.openURL(FEEDBACK_URL)}
            value="→"
          />
          <SettingRow label="Version" value={APP_VERSION} />
          <SettingRow label="Built with" value="Claude Sonnet 4.6" />
        </View>

        <View style={{ height: 48 }} />
      </ScrollView>
    </View>
  );
}

// ============================================================
// STYLES
// ============================================================
const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  header: {
    paddingHorizontal: 24,
    paddingTop: Platform.OS === 'ios' ? 60 : 28,
    paddingBottom: 16,
    borderBottomWidth: 0.5, borderBottomColor: C.border,
    backgroundColor: C.bg,
  },
  headerTitle: { fontFamily: 'Georgia', fontSize: 28, color: C.text, letterSpacing: 0.3 },
  scroll:        { flex: 1 },
  scrollContent: { paddingTop: 20, paddingBottom: 20 },

  sectionHeader: {
    fontSize: 11, color: C.light, letterSpacing: 0.8,
    textTransform: 'uppercase', paddingHorizontal: 24,
    paddingTop: 20, paddingBottom: 8,
  },
  group: {
    backgroundColor: C.white,
    borderTopWidth: 0.5, borderBottomWidth: 0.5, borderColor: C.border,
  },
  row: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 20, paddingVertical: 13,
    borderBottomWidth: 0.5, borderBottomColor: C.border, gap: 12, minHeight: 50,
  },
  rowPressed: { backgroundColor: C.surface },
  rowLeft:    { flex: 1, gap: 2 },
  rowLabel:   { fontSize: 15, color: C.text },
  rowSub:     { fontSize: 12, color: C.light, lineHeight: 17 },
  rowValue:   { fontSize: 14, color: C.light, flexShrink: 0 },

  tierBadge:     { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 5 },
  tierBadgeText: { fontSize: 12, fontWeight: '500' },

  upgradeArrow: {
    backgroundColor: C.accent, width: 28, height: 28,
    borderRadius: 14, alignItems: 'center', justifyContent: 'center',
  },

  thresholdRow: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  thresholdChip: {
    paddingHorizontal: 12, paddingVertical: 7, borderRadius: 6,
    borderWidth: 0.5, borderColor: C.border, backgroundColor: C.surface,
  },
  thresholdChipActive:     { backgroundColor: C.accent, borderColor: C.accent },
  thresholdChipText:       { fontSize: 13, color: C.muted },
  thresholdChipTextActive: { color: C.white, fontWeight: '500' },
  lockedNote: { fontSize: 12, color: C.light, fontStyle: 'italic' },

  privacyNote: {
    margin: 16, padding: 14, backgroundColor: C.accentLight,
    borderRadius: 8, borderWidth: 0.5, borderColor: '#D4B898', gap: 6,
  },
  privacyTitle: { fontFamily: 'Georgia', fontSize: 14, color: C.accent },
  privacyBody:  { fontSize: 13, color: C.muted, lineHeight: 19 },
});

const sp = StyleSheet.create({
  connectBlock: { padding: 16, gap: 10 },
  connectLabel: { fontSize: 12, color: C.muted, letterSpacing: 0.5 },
  inputRow: { flexDirection: 'row', gap: 8, alignItems: 'center' },
  input: {
    flex: 1, fontSize: 14, color: C.text, backgroundColor: C.surface,
    borderRadius: 8, paddingHorizontal: 12, paddingVertical: 10,
    borderWidth: 0.5, borderColor: C.border,
  },
  sendBtn: {
    backgroundColor: C.accent, borderRadius: 8,
    paddingHorizontal: 16, paddingVertical: 10,
    alignItems: 'center', justifyContent: 'center',
  },
  sendBtnText: { color: C.white, fontSize: 14, fontWeight: '500' },
  backLink: { fontSize: 13, color: C.accent, marginTop: 2 },
  connectedBadge: {
    backgroundColor: C.sageLt, paddingHorizontal: 10,
    paddingVertical: 4, borderRadius: 5,
  },
  connectedBadgeText: { fontSize: 12, color: C.sage, fontWeight: '500' },
});
