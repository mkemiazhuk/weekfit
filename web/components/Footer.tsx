"use client";

import Wordmark from "./Wordmark";
import FooterWaitlist from "./FooterWaitlist";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { useWaitlist } from "@/lib/waitlist";

function FooterLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a href={href} className="footer-link">
      <span className="footer-link__text">{children}</span>
    </a>
  );
}

function NavGroup({
  title,
  links,
  className,
}: {
  title: string;
  links: { label: string; href: string }[];
  className?: string;
}) {
  return (
    <nav className={className} aria-label={title}>
      <h3 className="footer-nav-title">{title}</h3>
      <ul className="footer-nav-list">
        {links.map((l) => (
          <li key={l.href}>
            <FooterLink href={l.href}>{l.label}</FooterLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}

function SocialIcon({ label, href, children }: { label: string; href: string; children: React.ReactNode }) {
  return (
    <a
      href={href}
      className="footer-social"
      aria-label={label}
      {...(href.startsWith("http") ? { target: "_blank", rel: "noreferrer noopener" } : {})}
    >
      {children}
    </a>
  );
}

export default function Footer() {
  const { t, localePath } = useI18n();
  const { openWaitlist } = useWaitlist();
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
  ];

  const legalLinks = [
    { label: t.footer.privacy, href: localePath("/privacy") },
    { label: t.footer.terms, href: localePath("/terms") },
    { label: t.footer.contact, href: localePath("/contact") },
  ];

  const xUrl = SITE.social.x;
  const instagramUrl = SITE.social.instagram;

  return (
    <footer className="footer-premium" aria-labelledby="footer-heading">
      <div className="footer-premium__atmosphere" aria-hidden>
        <div className="footer-premium__glow footer-premium__glow--green" />
        <div className="footer-premium__glow footer-premium__glow--gold" />
      </div>

      <div className="footer-premium__inner">
        <h2 id="footer-heading" className="sr-only">
          {t.footer.ariaLabel}
        </h2>

        <div className="footer-composition">
          <div className="footer-brand">
            <Wordmark size="footer" className="footer-brand__logo" />
            <p className="footer-brand__tagline">{t.footer.tagline}</p>
            <button type="button" className="footer-cta-quiet footer-brand__cta" onClick={openWaitlist}>
              {t.footer.notify}
            </button>
            <ul className="footer-socials" aria-label={t.footer.socialLabel}>
              {xUrl && (
                <li>
                  <SocialIcon label="X" href={xUrl}>
                    <svg viewBox="0 0 24 24" width={15} height={15} fill="currentColor" aria-hidden>
                      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231 5.451-6.231zm-1.161 17.52h1.833L7.084 4.126H5.117L17.083 19.77z" />
                    </svg>
                  </SocialIcon>
                </li>
              )}
              {instagramUrl && (
                <li>
                  <SocialIcon label="Instagram" href={instagramUrl}>
                    <svg viewBox="0 0 24 24" width={15} height={15} fill="none" stroke="currentColor" strokeWidth={1.6} aria-hidden>
                      <rect x="3.5" y="3.5" width="17" height="17" rx="5" />
                      <circle cx="12" cy="12" r="4" />
                      <circle cx="17.2" cy="6.8" r="1" fill="currentColor" stroke="none" />
                    </svg>
                  </SocialIcon>
                </li>
              )}
              <li>
                <SocialIcon label="Email" href={`mailto:${SITE.email}`}>
                  <svg viewBox="0 0 24 24" width={15} height={15} fill="none" stroke="currentColor" strokeWidth={1.6} aria-hidden>
                    <rect x="3" y="5.5" width="18" height="13" rx="2" />
                    <path d="M3 7.5l9 6.5 9-6.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </SocialIcon>
              </li>
            </ul>
          </div>

          <div className="footer-nav-grid">
            <NavGroup title={t.footer.product} links={productLinks} className="footer-nav-group" />
            <NavGroup title={t.footer.resources} links={resourceLinks} className="footer-nav-group" />
            <NavGroup title={t.footer.legal} links={legalLinks} className="footer-nav-group" />
          </div>

          <FooterWaitlist />
        </div>

        <div className="footer-bottom">
          <p className="footer-meta">
            <span>© {year} WeekFit</span>
            <span aria-hidden className="footer-meta__dot">
              ·
            </span>
            <span>{t.footer.rights}</span>
            <span aria-hidden className="footer-meta__dot">
              ·
            </span>
            <span>{t.footer.disclaimer}</span>
          </p>

          <ul className="footer-trust" aria-label={t.footer.trustLabel}>
            <li className="footer-trust-item">
              <svg viewBox="0 0 24 24" width={13} height={13} fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
                <path d="M12 3l8 3v6c0 5-3.5 8.5-8 11-4.5-2.5-8-6-8-11V6l8-3z" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              {t.footer.trust.data}
            </li>
            <li className="footer-trust-item">
              <svg viewBox="0 0 24 24" width={13} height={13} fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
                <rect x="5" y="11" width="14" height="10" rx="2" />
                <path d="M8 11V8a4 4 0 0 1 8 0v3" strokeLinecap="round" />
              </svg>
              {t.footer.trust.privacy}
            </li>
            <li className="footer-trust-item">
              <svg viewBox="0 0 24 24" width={13} height={13} fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
                <path d="M12 21s-7-4.35-7-9.5A3.5 3.5 0 0 1 12 8a3.5 3.5 0 0 1 7 3.5C19 16.65 12 21 12 21z" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              {t.footer.trust.health}
            </li>
          </ul>
        </div>
      </div>
    </footer>
  );
}
