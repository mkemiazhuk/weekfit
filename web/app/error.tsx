"use client";

import Link from "next/link";

export default function Error({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="mx-auto flex min-h-[50vh] max-w-lg flex-col items-center justify-center section-x py-24 text-center">
      <h1 className="display text-[1.75rem] text-white">Something went wrong</h1>
      <p className="body-md mt-3 text-white/55">
        An unexpected error occurred. You can try again or return to the homepage.
      </p>
      <div className="mt-8 flex flex-wrap justify-center gap-3">
        <button
          type="button"
          onClick={reset}
          className="btn btn-primary min-h-[44px] px-5"
        >
          Try again
        </button>
        <Link href="/" className="btn btn-ghost min-h-[44px] px-5">
          Home
        </Link>
      </div>
    </div>
  );
}
