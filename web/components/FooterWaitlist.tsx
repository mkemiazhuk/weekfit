"use client";

import { useId } from "react";
import { useI18n } from "@/lib/i18n";
import { useWaitlist } from "@/lib/waitlist";

export default function FooterWaitlist() {
  const { t } = useI18n();
  const w = t.footer.waitlist;
  const titleId = useId();
  const { openWaitlist } = useWaitlist();

  return (
    <aside id="footer-waitlist" className="footer-waitlist" aria-labelledby={titleId}>
      <h2 id={titleId} className="footer-waitlist__title">
        {w.title}
      </h2>
      <button type="button" className="footer-cta-quiet" onClick={openWaitlist}>
        {w.button}
      </button>
    </aside>
  );
}
