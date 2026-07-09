import type { DocSection } from "@/lib/content";

export default function DocArticle({ sections }: { sections: DocSection[] }) {
  return (
    <>
      {sections.map((s) => (
        <section key={s.id} id={s.id}>
          {s.h ? <h2>{s.h}</h2> : null}
          {s.blocks.map((b, i) => {
            if (b.t === "p") return <p key={i}>{b.v}</p>;
            if (b.t === "h3") return <h3 key={i}>{b.v}</h3>;
            if (b.t === "ul")
              return (
                <ul key={i}>
                  {b.v.map((x, j) => (
                    <li key={j}>{x}</li>
                  ))}
                </ul>
              );
            return null;
          })}
        </section>
      ))}
    </>
  );
}
