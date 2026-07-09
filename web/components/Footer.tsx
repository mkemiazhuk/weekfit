"use client";

import Wordmark from "./Wordmark";
import Button from "./Button";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";

const linkClass =
  "flex min-h-[44px] items-center text-[15px] text-white/70 transition-colors hover:text-white active:text-white md:min-h-0 md:text-[14px]";

function LinkColumn({
  title,
  links,
  listClassName,
  className,
}: {
  title: string;
  links: { label: string; href: string }[];
  listClassName?: string;
  className?: string;
}) {
  return (
    <div className={className}>
      <h2 className="text-[11px] font-semibold uppercase tracking-[0.14em] text-white/45 md:text-[12px] md:tracking-[0.12em] md:text-white/50">
        {title}
      </h2>
      <ul className={`mt-2 space-y-0 md:mt-4 md:space-y-3 ${listClassName ?? ""}`}>
        {links.map((l) => (
          <li key={l.href}>
            <a href={l.href} className={linkClass}>
              {l.label}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default function Footer() {
  const { t, localePath } = useI18n();
  const year = new Date().getFullYear();

  const productLinks = [
    { label: t.footer.experience, href: localePath("/#experience") },
    { label: t.footer.pillars, href: localePath("/#pillars") },
    { label: t.footer.download, href: localePath("/download") },
  ];

  const resourceLinks = [
    { label: t.footer.support, href: localePath("/support") },
    { label: t.footer.faq, href: localePath("/faq") },
    { label: t.footer.blog, href: localePath("/blog") },
    { label: t.footer.changelog, href: localePath("/changelog") },
    { label: t.footer.press, href: localePath("/press") },
  ];

  const legalLinks = [
    { label: t.footer.privacy, href: localePath("/privacy") },
    { label: t.footer.terms, href: localePath("/terms") },
    { label: t.footer.contact, href: localePath("/contact") },
  ];

  return (
    <footer className="relative border-t border-white/[0.07] px-5 pt-12 md:px-6 md:pt-20">
      <div className="mx-auto max-w-6xl">
        {/* Mobile layout */}
        <div className="md:hidden">
          <div className="space-y-3">
            <Wordmark size="lg" />
            <p className="max-w-[36ch] text-[13px] leading-relaxed text-white/50">
              {t.footer.tagline}
            </p>
          </div>

          <div className="mt-6 flex gap-2">
            <a
              href={localePath("/blog")}
              className="flex-1 rounded-full border border-white/10 bg-white/[0.04] py-2.5 text-center text-[13px] font-medium text-white/75"
            >
              {t.footer.blog}
            </a>
            <a
              href={localePath("/changelog")}
              className="flex-1 rounded-full border border-white/10 bg-white/[0.04] py-2.5 text-center text-[13px] font-medium text-white/75"
            >
              {t.footer.changelog}
            </a>
          </div>

          <div className="mt-6">
            <Button href={SITE.appInstallUrl} external className="w-full">
              {t.cta.testflight}
            </Button>
            <p className="mt-2 text-center text-[11px] uppercase tracking-[0.14em] text-white/35">
              {t.cta.testflightNote}
            </p>
          </div>

          <div className="mt-8 rounded-[22px] border border-white/[0.08] bg-white/[0.03] p-5">
            <div className="grid grid-cols-2 gap-x-6 gap-y-7">
              <LinkColumn title={t.footer.product} links={productLinks} />
              <LinkColumn title={t.footer.resources} links={resourceLinks} />
              <LinkColumn
                title={t.footer.legal}
                links={legalLinks}
                className="col-span-2 border-t border-white/[0.06] pt-7"
              />
            </div>
          </div>
        </div>

        {/* Desktop layout */}
        <div className="hidden gap-12 md:grid md:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div>
            <Wordmark size="lg" />
            <p className="mt-4 max-w-[34ch] text-[14px] leading-relaxed text-white/50">
              {t.footer.tagline}
            </p>
            <div className="mt-5 flex flex-wrap gap-2">
              <a
                href={localePath("/blog")}
                className="rounded-full border border-white/10 bg-white/[0.04] px-3.5 py-1.5 text-[13px] font-medium text-white/75 transition-colors hover:text-white"
              >
                {t.footer.blog}
              </a>
              <a
                href={localePath("/changelog")}
                className="rounded-full border border-white/10 bg-white/[0.04] px-3.5 py-1.5 text-[13px] font-medium text-white/75 transition-colors hover:text-white"
              >
                {t.footer.changelog}
              </a>
            </div>
          </div>
          <LinkColumn title={t.footer.product} links={productLinks} />
          <LinkColumn title={t.footer.resources} links={resourceLinks} />
          <LinkColumn title={t.footer.legal} links={legalLinks} />
        </div>
      </div>

      <div className="mx-auto mt-10 max-w-6xl border-t border-white/[0.06] pt-6 pb-[max(1.25rem,env(safe-area-inset-bottom))] md:mt-16 md:pt-8 md:pb-16">
        <p className="text-pretty text-[13px] leading-relaxed text-white/50">
          © {year} WeekFit. {t.footer.rights} {t.footer.disclaimer}
        </p>
      </div>
    </footer>
  );
}
