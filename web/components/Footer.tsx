"use client";

import Wordmark from "./Wordmark";
import { useI18n } from "@/lib/i18n";

export default function Footer() {
  const { t } = useI18n();
  const year = new Date().getFullYear();

  const columns = [
    {
      title: t.footer.product,
      links: [
        { label: t.footer.experience, href: "/#experience" },
        { label: t.footer.pillars, href: "/#pillars" },
        { label: t.footer.download, href: "/download" },
      ],
    },
    {
      title: t.footer.resources,
      links: [
        { label: t.footer.support, href: "/support" },
        { label: t.footer.faq, href: "/faq" },
        { label: t.footer.changelog, href: "/changelog" },
        { label: t.footer.press, href: "/press" },
      ],
    },
    {
      title: t.footer.legal,
      links: [
        { label: t.footer.privacy, href: "/privacy" },
        { label: t.footer.terms, href: "/terms" },
        { label: t.footer.contact, href: "mailto:support@weekfit.app" },
      ],
    },
  ];

  return (
    <footer className="relative border-t border-white/[0.07] px-6 pb-16 pt-20">
      <div className="mx-auto grid max-w-6xl gap-12 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <Wordmark />
          <p className="mt-4 max-w-[34ch] text-[14px] leading-relaxed text-white/50">
            {t.footer.tagline}
          </p>
        </div>
        {columns.map((col) => (
          <div key={col.title}>
            <h4 className="text-[12px] font-semibold uppercase tracking-[0.12em] text-white/40">
              {col.title}
            </h4>
            <ul className="mt-4 space-y-3">
              {col.links.map((l) => (
                <li key={l.label}>
                  <a
                    href={l.href}
                    className="text-[14px] text-white/65 transition-colors hover:text-white"
                  >
                    {l.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="mx-auto mt-16 max-w-6xl border-t border-white/[0.06] pt-8">
        <p className="text-[13px] text-white/40">
          © {year} WeekFit. {t.footer.rights}
        </p>
        <p className="mt-3 max-w-[62ch] text-[12px] leading-relaxed text-white/30">
          {t.footer.disclaimer}
        </p>
      </div>
    </footer>
  );
}
