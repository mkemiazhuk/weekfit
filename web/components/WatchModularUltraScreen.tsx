import Image from "next/image";

/** Flat cycling workout screen — cropped from Apple reference art. */
export default function WatchModularUltraScreen() {
  return (
    <div className="watch-modular" aria-hidden>
      <Image
        src="/img/watch-modular-ultra-face.png"
        alt=""
        fill
        sizes="200px"
        className="watch-modular__img"
        unoptimized
      />
    </div>
  );
}
