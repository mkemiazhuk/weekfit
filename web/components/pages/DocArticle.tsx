import type { DocSection } from "@/lib/content";

export default function DocArticle({ sections }: { sections: DocSection[] }) {
  return (
    <>
      {sections.map((s) => (
        <section key={s.id} id={s.id}>
          <h2>{s.h}</h2>
          {s.blocks.map((b, i) => {
            if (b.t === "p") return <p key={i}>{b.v}</p>;
            if (b.t === "h3") return <h3 key={i}>{b.v}</h3>;
            return (
              <ul key={i}>
                {b.v.map((x, j) => (
                  <li key={j}>{x}</li>
                ))}
              </ul>
            );
          })}
        </section>
      ))}
    </>
  );
}
