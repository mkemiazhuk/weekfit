import Script from "next/script";
import { SITE } from "@/lib/site";

/**
 * Privacy-friendly analytics. Nothing loads unless explicitly configured via
 * environment variables — no cookies, no third-party trackers by default.
 *
 *   Plausible (preferred, cookieless):
 *     NEXT_PUBLIC_PLAUSIBLE_DOMAIN=weekfit.app
 *   Google Analytics 4 (optional):
 *     NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
 */
export default function Analytics() {
  const { plausibleDomain, plausibleSrc, gaId } = SITE.analytics;

  return (
    <>
      {plausibleDomain ? (
        <Script
          defer
          data-domain={plausibleDomain}
          src={plausibleSrc}
          strategy="afterInteractive"
        />
      ) : null}

      {gaId ? (
        <>
          <Script
            src={`https://www.googletagmanager.com/gtag/js?id=${gaId}`}
            strategy="afterInteractive"
          />
          <Script id="ga4-init" strategy="afterInteractive">
            {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${gaId}',{anonymize_ip:true});`}
          </Script>
        </>
      ) : null}
    </>
  );
}
