"use client";

import { FormEvent, useEffect, useId, useRef, useState } from "react";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";

export default function WaitlistDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const w = t.footer.waitlist;
  const formId = useId();
  const dialogRef = useRef<HTMLDialogElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "done" | "error">("idle");

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      dialog.showModal();
      window.setTimeout(() => inputRef.current?.focus(), 80);
    }
    if (!open && dialog.open) dialog.close();
  }, [open]);

  const handleClose = () => {
    onClose();
    if (status === "done") {
      setStatus("idle");
      setEmail("");
    }
  };

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
    <dialog
      ref={dialogRef}
      className="waitlist-dialog"
      aria-labelledby={`${formId}-title`}
      onCancel={(e) => {
        e.preventDefault();
        handleClose();
      }}
      onClick={(e) => {
        if (e.target === dialogRef.current) handleClose();
      }}
    >
      <div className="waitlist-dialog__panel">
        <button
          type="button"
          className="waitlist-dialog__close"
          onClick={handleClose}
          aria-label={w.close}
        >
          <svg viewBox="0 0 24 24" width={16} height={16} fill="none" stroke="currentColor" strokeWidth={1.75} aria-hidden>
            <path d="M6 6l12 12M18 6L6 18" strokeLinecap="round" />
          </svg>
        </button>

        <h2 id={`${formId}-title`} className="waitlist-dialog__title">
          {w.title}
        </h2>
        <p className="waitlist-dialog__desc">{w.description}</p>

        {status === "done" ? (
          <p className="waitlist-dialog__success" role="status" aria-live="polite">
            {w.success}
          </p>
        ) : (
          <form className="waitlist-dialog__form" onSubmit={onSubmit} noValidate>
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
              className="waitlist-dialog__input"
              aria-invalid={status === "error"}
              aria-describedby={status === "error" ? `${formId}-error` : undefined}
            />
            {status === "error" && (
              <p id={`${formId}-error`} className="waitlist-dialog__error" role="alert">
                {w.error}
              </p>
            )}
            <button type="submit" className="waitlist-dialog__submit">
              {w.button}
            </button>
          </form>
        )}

        <p className="waitlist-dialog__note">{w.note}</p>
      </div>
    </dialog>
  );
}
