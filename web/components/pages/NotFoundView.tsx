"use client";

import { useI18n } from "@/lib/i18n";
import { notFound } from "@/lib/content";
import Button from "../Button";

export default function NotFoundView() {
  const { lang } = useI18n();
  const c = notFound[lang];
  return (
    <section className="mx-auto flex min-h-[80vh] max-w-2xl flex-col items-center justify-center px-6 text-center">
      <p
        className="display text-[clamp(5rem,18vw,10rem)] leading-none"
        style={{
          background: "linear-gradient(100deg, #66f070, #2edbfa)",
          WebkitBackgroundClip: "text",
          backgroundClip: "text",
          WebkitTextFillColor: "transparent",
        }}
      >
        404
      </p>
      <h1 className="display mt-4 text-[clamp(1.8rem,4vw,2.6rem)] text-white">
        {c.title}
      </h1>
      <p className="mt-4 max-w-[44ch] text-[1.1rem] leading-relaxed text-white/55">
        {c.lead}
      </p>
      <div className="mt-8">
        <Button href="/">{c.cta}</Button>
      </div>
    </section>
  );
}
