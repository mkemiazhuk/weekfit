"use client";

import Wordmark from "./Wordmark";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";

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
  const year = new Date().getFullYear();

  const productLinks = [
    { label: t.footer.experience, href: localePath("/#experience") },
    { label: t.footer.simulator, href: localePath("/experience") },
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
  const instagramUrl = SITE.instagramRedirectPath;

  return (
    <footer className="footer-premium" aria-labelledby="footer-heading">
      <div className="footer-premium__atmosphere" aria-hidden>
        <div className="footer-premium__glow footer-premium__glow--green" />
      </div>

      <div className="footer-premium__inner">
        <h2 id="footer-heading" className="sr-only">
          {t.footer.ariaLabel}
        </h2>

        <div className="footer-composition">
          <div className="footer-hero">
            <Wordmark size="footer" className="footer-hero__logo" />
            <p className="footer-hero__tagline">{t.footer.tagline}</p>
          </div>

          <ul className="footer-socials" aria-label={t.footer.socialLabel}>
            {xUrl && (
              <li>
                <SocialIcon label="X" href={xUrl}>
                  <svg viewBox="0 0 24 24" width={16} height={16} fill="currentColor" aria-hidden>
                    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231 5.451-6.231zm-1.161 17.52h1.833L7.084 4.126H5.117L17.083 19.77z" />
                  </svg>
                </SocialIcon>
              </li>
            )}
            {instagramUrl && (
              <li>
                <SocialIcon label="Instagram" href={instagramUrl}>
                  <svg viewBox="0 0 24 24" width={16} height={16} fill="none" stroke="currentColor" strokeWidth={1.6} aria-hidden>
                    <rect x="3.5" y="3.5" width="17" height="17" rx="5" />
                    <circle cx="12" cy="12" r="4" />
                    <circle cx="17.2" cy="6.8" r="1" fill="currentColor" stroke="none" />
                  </svg>
                </SocialIcon>
              </li>
            )}
            <li>
              <SocialIcon label="Email" href={`mailto:${SITE.email}`}>
                <svg viewBox="0 0 24 24" width={16} height={16} fill="none" stroke="currentColor" strokeWidth={1.6} aria-hidden>
                  <rect x="3" y="5.5" width="18" height="13" rx="2" />
                  <path d="M3 7.5l9 6.5 9-6.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </SocialIcon>
            </li>
          </ul>

          <div className="footer-nav-grid">
            <NavGroup title={t.footer.product} links={productLinks} className="footer-nav-group" />
            <NavGroup title={t.footer.resources} links={resourceLinks} className="footer-nav-group" />
            <NavGroup title={t.footer.legal} links={legalLinks} className="footer-nav-group" />
          </div>
        </div>

        <div className="footer-legal">
          <div className="footer-meta">
            <p className="footer-meta__line">
              © {year} WeekFit · {t.footer.rights}
            </p>
            <p className="footer-meta__disclaimer">{t.footer.disclaimer}</p>
          </div>
        </div>
      </div>
    </footer>
  );
}
