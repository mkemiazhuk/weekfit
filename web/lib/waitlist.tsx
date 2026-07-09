"use client";

import { createContext, useCallback, useContext, useMemo, useState } from "react";
import WaitlistDialog from "@/components/WaitlistDialog";

type WaitlistContextValue = {
  openWaitlist: () => void;
  closeWaitlist: () => void;
};

const WaitlistContext = createContext<WaitlistContextValue | null>(null);

export function WaitlistProvider({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(false);

  const openWaitlist = useCallback(() => setOpen(true), []);
  const closeWaitlist = useCallback(() => setOpen(false), []);

  const value = useMemo(
    () => ({ openWaitlist, closeWaitlist }),
    [openWaitlist, closeWaitlist]
  );

  return (
    <WaitlistContext.Provider value={value}>
      {children}
      <WaitlistDialog open={open} onClose={closeWaitlist} />
    </WaitlistContext.Provider>
  );
}

export function useWaitlist() {
  const ctx = useContext(WaitlistContext);
  if (!ctx) throw new Error("useWaitlist must be used within WaitlistProvider");
  return ctx;
}
