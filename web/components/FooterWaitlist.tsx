"use client";

import { FormEvent, useId, useRef, useState } from "react";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";

export default function FooterWaitlist() {
  const { t } = useI18n();
  const w = t.footer.waitlist;
  const formId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "done" | "error">("idle");

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const trimmed = email.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
      setStatus("error");
      return;
    }

    const endpoint = process.env.NEXT_PUBLIC_WAITLIST_ENDPOINT;
    if (endpoint) {
      try {
        const res = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({ email: trimmed }),
        });
        if (!res.ok) throw new Error("submit failed");
      } catch {
        setStatus("error");
        return;
      }
    } else {
      const subject = encodeURIComponent("WeekFit waitlist");
      const body = encodeURIComponent(`Please notify me at: ${trimmed}`);
      window.location.href = `mailto:${SITE.email}?subject=${subject}&body=${body}`;
    }

    setStatus("done");
  };

  return (
    <aside
      id="footer-waitlist"
      className="footer-waitlist premium-card"
      aria-labelledby={`${formId}-title`}
    >
      <div className="footer-waitlist__sheen" aria-hidden />
      <div className="footer-waitlist__glow" aria-hidden />

      <h2 id={`${formId}-title`} className="footer-waitlist__title">
        {w.title}
      </h2>
      <p className="footer-waitlist__desc">{w.description}</p>

      {status === "done" ? (
        <p className="footer-waitlist__success" role="status" aria-live="polite">
          {w.success}
        </p>
      ) : (
        <form className="footer-waitlist__form" onSubmit={onSubmit} noValidate>
          <label htmlFor={`${formId}-email`} className="sr-only">
            {w.placeholder}
          </label>
          <input
            ref={inputRef}
            id={`${formId}-email`}
            type="email"
            name="email"
            autoComplete="email"
            inputMode="email"
            placeholder={w.placeholder}
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              if (status === "error") setStatus("idle");
            }}
            className="footer-waitlist__input"
            aria-invalid={status === "error"}
            aria-describedby={status === "error" ? `${formId}-error` : undefined}
          />
          {status === "error" && (
            <p id={`${formId}-error`} className="footer-waitlist__error" role="alert">
              {w.error}
            </p>
          )}
          <button type="submit" className="footer-waitlist__submit">
            <span className="footer-waitlist__submit-bg" aria-hidden />
            <span className="footer-waitlist__submit-shine" aria-hidden />
            <span className="footer-waitlist__submit-label">{w.button}</span>
          </button>
        </form>
      )}

      <p className="footer-waitlist__note">{w.note}</p>
    </aside>
  );
}

export function scrollToFooterWaitlist() {
  const el = document.getElementById("footer-waitlist");
  const input = el?.querySelector("input[type=email]") as HTMLInputElement | null;
  el?.scrollIntoView({ behavior: "smooth", block: "center" });
  window.setTimeout(() => input?.focus(), 450);
}
