import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import * as SP from '../services/stashpass';

interface StashPassState {
  isConnected: boolean;
  userId: string | null;
  requestOtp:  (contact: string) => Promise<string | null>;
  verifyOtp:   (contact: string, otp: string) => Promise<void>;
  disconnect:  () => Promise<void>;
}

const StashPassContext = createContext<StashPassState>({
  isConnected: false,
  userId: null,
  requestOtp:  async () => null,
  verifyOtp:   async () => {},
  disconnect:  async () => {},
});

export function StashPassProvider({ children }: { children: React.ReactNode }) {
  const [isConnected, setIsConnected] = useState(false);
  const [userId, setUserId]           = useState<string | null>(null);

  // Rehydrate auth state from SecureStore on mount
  useEffect(() => {
    SP.getStoredTokens().then(tokens => {
      if (tokens) {
        setIsConnected(true);
        setUserId(tokens.userId);
      }
    });
  }, []);

  const requestOtp = useCallback(async (contact: string): Promise<string | null> => {
    return SP.requestOtp(contact);
  }, []);

  const verifyOtp = useCallback(async (contact: string, otp: string) => {
    const result = await SP.verifyOtp(contact, otp);
    setUserId(result.userId);
    setIsConnected(true);
  }, []);

  const disconnect = useCallback(async () => {
    await SP.logout();
    setIsConnected(false);
    setUserId(null);
  }, []);

  return (
    <StashPassContext.Provider value={{ isConnected, userId, requestOtp, verifyOtp, disconnect }}>
      {children}
    </StashPassContext.Provider>
  );
}

export function useStashPass(): StashPassState {
  return useContext(StashPassContext);
}
