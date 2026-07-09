"use client";

import { useI18n } from "@/lib/i18n";
import { notFound } from "@/lib/content";
import Button from "../Button";

export default function NotFoundView() {
  const { lang, localePath } = useI18n();
  const c = notFound[lang];
  return (
    <section className="mx-auto flex min-h-[80vh] max-w-2xl flex-col items-center justify-center section-x text-center">
      <p
        className="display text-gradient-hero text-[clamp(5rem,18vw,10rem)] leading-none"
      >
        404
      </p>
      <h1 className="display mt-4 text-[clamp(1.8rem,4vw,2.6rem)] text-white">
        {c.title}
      </h1>
      <p className="body-lg mt-4 max-w-[44ch]">
        {c.lead}
      </p>
      <div className="mt-8">
        <Button href={localePath("/")}>{c.cta}</Button>
      </div>
    </section>
  );
}
