"use client";

import { useI18n } from "@/lib/i18n";
import { terms } from "@/lib/content";
import { pastels } from "@/lib/tokens";
import PageHero from "../PageHero";
import DocLayout from "../DocLayout";
import DocArticle from "./DocArticle";

export default function TermsView() {
  const { lang } = useI18n();
  const c = terms[lang];
  return (
    <>
      <PageHero kicker={c.kicker} kickerColor={pastels.workout} title={c.title} lead={c.lead} />
      <p className="mb-10 text-center text-[13px] text-white/40">{c.updated}</p>
      <DocLayout
        tocTitle={c.tocTitle}
        toc={c.sections.map((s) => ({ id: s.id, label: s.h }))}
      >
        <DocArticle sections={c.sections} />
      </DocLayout>
    </>
  );
}
